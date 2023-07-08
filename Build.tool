#!/usr/bin/env python3

import os
import subprocess

from pathlib import Path

XCODE_PROJECT:         str = "Desktop-Cleanup.xcodeproj"
LAUNCH_AGENT:          str = "Launch Agent/com.khronokernel.Desktop-Cleanup.plist"
INSTALL_PKG_SCRIPTS:   str = "Package Scripts (Install)"
UNINSTALL_PKG_SCRIPTS: str = "Package Scripts (Uninstall)"

BUILD_DIR:             str = "build"
CLI_BUILD_DIR:         str = BUILD_DIR + "/CLI"
PKG_BUILD_DIR:         str = BUILD_DIR + "/PKG"


class GenerateProject:

    def __init__(self) -> None:
        os.chdir(os.path.dirname(os.path.realpath(__file__)))

        self._version = self._fetch_version()
        print(f"Building version: {self._version}")

        self._prepare_cwd()
        self._build_application()
        self._build_uninstall_package()
        self._build_install_package()

    def _prepare_cwd(self) -> None:
        """
        Prepare the current working directory for building.
        """
        if Path(BUILD_DIR).exists():
            subprocess.run(["rm", "-rf", BUILD_DIR])
        subprocess.run(["mkdir", BUILD_DIR])


    def _fetch_version(self) -> str:
        """
        Fetch the application version from the main.swift file.
        """
        with open("Desktop-Cleanup/main.swift", "r") as file:
            for line in file:
                if line.startswith("let APPLICATION_VERSION"):
                    return line.split("\"")[1]
        raise Exception("Failed to fetch application version")


    def _build_application(self) -> None:
        """
        Call 'xcodebuild' to build the application.
        """
        print(f"Building application...")
        result = subprocess.run([
            "xcodebuild",
            "-project", XCODE_PROJECT,
            "-scheme", "Desktop-Cleanup",
            "-configuration", "Release",
            "SYMROOT=build/CLI",
            "clean", "build"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(result.stderr.decode("utf-8"))
            raise Exception("Failed to build application")


    def _build_uninstall_package(self) -> None:
        """
        Call 'pkgbuild' to build the uninstall package.
        """
        print("Building uninstall package...")
        for script in Path(UNINSTALL_PKG_SCRIPTS).iterdir():
            subprocess.run(["chmod", "+x", str(script)])

        result = subprocess.run([
            "pkgbuild",
            "--identifier", "com.khronokernel.Desktop-Cleanup",
            "--version", self._version,
            "--scripts", UNINSTALL_PKG_SCRIPTS,
            "--nopayload",
            "build/Desktop-Cleanup-Uninstall.pkg"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(result.stderr.decode("utf-8"))
            raise Exception("Failed to build package")


    def _build_install_package(self) -> None:
        """
        Call 'pkgbuild' to build the install package.
        """
        print("Building install package...")
        dirs_to_create = [
            PKG_BUILD_DIR,
            PKG_BUILD_DIR + "/usr/local/bin",
            PKG_BUILD_DIR + "/Library/LaunchAgents"
        ]
        for directory in dirs_to_create:
            if not Path(directory).exists():
                subprocess.run(["mkdir", "-p", directory])

        subprocess.run(["cp", CLI_BUILD_DIR + "/Release/Desktop-Cleanup", PKG_BUILD_DIR + "/usr/local/bin/Desktop-Cleanup"])
        subprocess.run(["cp", LAUNCH_AGENT, PKG_BUILD_DIR + "/Library/LaunchAgents/com.khronokernel.Desktop-Cleanup.plist"])

        for script in Path(INSTALL_PKG_SCRIPTS).iterdir():
            subprocess.run(["chmod", "+x", str(script)])

        result = subprocess.run([
            "pkgbuild",
            "--root", PKG_BUILD_DIR,
            "--identifier", "com.khronokernel.Desktop-Cleanup",
            "--version", self._version,
            "--scripts", INSTALL_PKG_SCRIPTS,
            "build/Desktop-Cleanup.pkg"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            print(result.stderr.decode("utf-8"))
            raise Exception("Failed to build package")


if __name__ == "__main__":
    GenerateProject()