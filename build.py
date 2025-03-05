"""
build.py: Build executable and PKG
"""

import time
import argparse
import subprocess
import mac_signing_buddy
import macos_pkg_builder


class SubprocessErrorLogging:
    """
    Display subprocess error output.
    """
    def __init__(self, process: subprocess.CompletedProcess) -> None:
        self.process = process


    def __str__(self) -> str:
        """
        Display subprocess error output in formatted string.

        Format:

        Command: <command>
        Return Code: <return code>
        Standard Output:
            <standard output line 1>
            <standard output line 2>
            ...
        Standard Error:
            <standard error line 1>
            <standard error line 2>
            ...
        """
        output = "Error: Subprocess failed.\n"
        output += f"    Command: {self.process.args}\n"
        output += f"    Return Code: {self.process.returncode}\n"
        output += f"    Standard Output:\n"
        output += self._format_output(self.process.stdout.decode("utf-8"))
        output += f"    Standard Error:\n"
        output += self._format_output(self.process.stderr.decode("utf-8"))

        return output


    def _format_output(self, output: str) -> str:
        """
        Format output.
        """
        if not output:
            return "        None\n"

        result = "\n".join([f"        {line}" for line in output.split("\n") if line not in ["", "\n"]])
        if not result.endswith("\n"):
            result += "\n"

        return result


    def log(self) -> None:
        """
        Log subprocess error output.
        """
        print(str(self))


class Build:

    def __init__(self,
            executable_signing_identity: str = None,
            pkg_signing_identity:        str = None,

            notarization_apple_id:       str = None,
            notarization_password:       str = None,
            notarization_team_id:           str = None
        ):
        self._product_name          = "desktop-cleanup"
        self._product_target_arm64  = "arm64-apple-macos11"
        self._product_target_x86_64 = "x86_64-apple-macos10.10"

        self._executable_signing_identity = executable_signing_identity
        self._pkg_signing_identity        = pkg_signing_identity

        self._notarization_apple_id = notarization_apple_id
        self._notarization_password = notarization_password
        self._notarization_team_id  = notarization_team_id


    def _installer_pkg_welcome_message(self) -> str:
        """
        Generate installer README message for PKG
        """
        message = [
            "# Overview",
            f"This package will install Desktop-Cleanup on your system.",
            "# Files Installed",
            "Installation of this package will add the following files to your system:\n",
            "* `/usr/local/bin/desktop-cleanup`\n",
            "* `/Library/LaunchDaemons/com.khronokernel.desktop-cleanup.plist`",
        ]
        return "\n".join(message)


    def _uninstaller_pkg_welcome_message(self) -> str:
        """
        Generate uninstaller README message for PKG
        """
        message = [
            "# Overview",
            f"This package will uninstall Desktop-Cleanup from your system.",
            "# Files Removed",
            "Uninstallation of this package will remove the following files from your system:\n",
            "* `/usr/local/bin/desktop-cleanup`\n",
            "* `/Library/LaunchDaemons/com.khronokernel.desktop-cleanup.plist`",
        ]
        return "\n".join(message)


    def _resolve_version(self) -> str:
        """
        Resolve the version from the source code
        """
        with open("Source/desktop-cleanup/Library/Constants.swift", "r") as f:
            for line in f:
                if not line.startswith("let projectVersion    = \""):
                    continue
                return line.split("\"")[1]
        raise Exception("Failed to resolve version")


    def _build_executable(self, target: str) -> None:
        """
        Build the executable for the specified target
        """
        print(f"Building executable for target: {target}")
        result = subprocess.run(
            [
                "/usr/bin/swift", "build", "--product", self._product_name,
                "-Xswiftc", "-target", "-Xswiftc", target
            ],
            capture_output=True
        )
        if result.returncode != 0:
            SubprocessErrorLogging(result).log()
            raise Exception("Failed to build executable")

        result = subprocess.run(
            [
                "/bin/cp", f".build/debug/{self._product_name}", f".build/{self._product_name}-{target}"
            ],
            capture_output=True
        )
        if result.returncode != 0:
            SubprocessErrorLogging(result).log()
            raise Exception("Failed to copy executable")


    def _sign_executable(self, executable: str) -> None:
        """
        Sign the executable
        """
        print(f"Signing executable: {executable}")
        mac_signing_buddy.Sign(
            file=executable,
            identity=self._executable_signing_identity,
        ).sign()


    def _notarize_file(self, file: str) -> None:
        """
        Notarize the file
        """
        print(f"Notarizing file: {file}")
        mac_signing_buddy.Notarize(
            file=file,
            apple_id=self._notarization_apple_id,
            password=self._notarization_password,
            team_id=self._notarization_team_id
        ).sign()


    def _merge_executables(self, executables: list[str]) -> None:
        """
        Merge the executables into a single FAT binary
        """
        print("Merging executables into FAT binary")
        result = subprocess.run(
            [
                "/usr/bin/lipo", "-create", *executables, "-output", f".build/{self._product_name}"
            ],
            capture_output=True
        )
        if result.returncode != 0:
            SubprocessErrorLogging(result).log()
            raise Exception("Failed to merge executables")


    def _convert_to_pkg(self) -> None:
        """
        Generate a PKG file from the executable
        """
        print("Converting executable to PKG")
        _version = self._resolve_version()
        pkg_obj = macos_pkg_builder.Packages(
            pkg_output=f".build/{self._product_name.capitalize()}-Installer.pkg",
            pkg_bundle_id="com.khronokernel.desktop-cleanup.installer",
            pkg_version=_version,
            pkg_as_distribution=True,
            pkg_title=f"Desktop-Cleanup v{_version}",
            pkg_welcome=self._installer_pkg_welcome_message(),
            pkg_file_structure={
                ".build/desktop-cleanup": "/usr/local/bin/desktop-cleanup",
                "Source/launch services/com.khronokernel.desktop-cleanup.plist": "/Library/LaunchAgents/com.khronokernel.desktop-cleanup.plist"
            },
            pkg_preinstall_script="Source/install scripts/remove.sh",
            pkg_postinstall_script="Source/install scripts/install.sh",
            **({ "pkg_signing_identity": self._pkg_signing_identity } if self._pkg_signing_identity else {}),
        )
        assert pkg_obj.build() is True

        pkg_obj = macos_pkg_builder.Packages(
            pkg_output=f".build/{self._product_name.capitalize()}-Uninstaller.pkg",
            pkg_bundle_id="com.khronokernel.desktop-cleanup.uninstaller",
            pkg_version=_version,
            pkg_as_distribution=True,
            pkg_title=f"Desktop-Cleanup Uninstaller v{_version}",
            pkg_welcome=self._uninstaller_pkg_welcome_message(),
            pkg_preinstall_script="Source/install scripts/remove.sh",
            **({ "pkg_signing_identity": self._pkg_signing_identity } if self._pkg_signing_identity else {}),
        )
        assert pkg_obj.build() is True


    def build(self) -> None:
        """
        Build the executable and PKG
        """
        self._build_executable(self._product_target_arm64)
        self._build_executable(self._product_target_x86_64)

        self._merge_executables([
            f".build/{self._product_name}-{self._product_target_arm64}",
            f".build/{self._product_name}-{self._product_target_x86_64}"
        ])

        if self._executable_signing_identity is not None:
            self._sign_executable(f".build/{self._product_name}")

        if all([
            self._notarization_apple_id is not None,
            self._notarization_password is not None,
            self._notarization_team_id is not None
        ]):
            self._notarize_file(f".build/{self._product_name}")

        self._convert_to_pkg()

        if all([
            self._pkg_signing_identity is not None,
            self._notarization_apple_id is not None,
            self._notarization_password is not None,
            self._notarization_team_id is not None
        ]):
            self._notarize_file(f".build/{self._product_name.capitalize()}-Installer.pkg")
            self._notarize_file(f".build/{self._product_name.capitalize()}-Uninstaller.pkg")


if __name__ == "__main__":
    start_time = time.time()

    parser = argparse.ArgumentParser(description="Build Project")

    parser.add_argument("--executable-signing-identity", help="The signing identity for the executable")
    parser.add_argument("--pkg-signing-identity", help="The signing identity for the PKG")
    parser.add_argument("--notarization-apple-id", help="The notarization Apple ID")
    parser.add_argument("--notarization-password", help="The notarization password")
    parser.add_argument("--notarization-team-id", help="The notarization Team ID")

    args = parser.parse_args()

    Build(
        executable_signing_identity=args.executable_signing_identity,
        pkg_signing_identity=args.pkg_signing_identity,
        notarization_apple_id=args.notarization_apple_id,
        notarization_password=args.notarization_password,
        notarization_team_id=args.notarization_team_id
    ).build()

    print(f"Build completed in {time.time() - start_time:.2f} seconds")

