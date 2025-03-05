#!/bin/zsh --no-rcs
# -----------------------------------------------
# Load new installation
# -----------------------------------------------


# MARK: Variables
# -----------------------------------------------
launchServicePrefix="com.khronokernel.desktop-cleanup"
launchServiceFileCore="/Library/LaunchAgents/${launchServicePrefix}.plist"
installationDestinationCore="/usr/local/bin/desktop-cleanup"


# MARK: Functions
# -----------------------------------------------

# Install Swift 5 Runtime Support if required
function installSwiftRuntimeSupport() {
    # On macOS 10.14.4 and later, macOS ships with a built-in Swift Runtime
    # For older OSes, we need to install the Swift 5 Runtime Support PKG
    # Ref: https://support.apple.com/en-us/106446

    local osVersion

    osVersion=$(/usr/bin/sw_vers -productVersion)

    osMajorVersion=$(echo "$osVersion" | /usr/bin/awk -F. '{print $1}')
    osMinorVersion=$(echo "$osVersion" | /usr/bin/awk -F. '{print $2}')
    osPatchVersion=$(echo "$osVersion" | /usr/bin/awk -F. '{print $3}')

    if [[ "$osMajorVersion" -gt 10 ]]; then
        return
    fi

    if [[ "$osMinorVersion" -gt 14 ]]; then
        return
    fi

    if [[ "$osMinorVersion" -eq 14 ]] && [[ "$osPatchVersion" -gt 4 ]]; then
        return
    fi

    local swiftRuntimePkgReceipt="com.apple.pkg.SwiftRuntimeForCommandLineTools"
    if /usr/sbin/pkgutil --pkgs | /usr/bin/grep "$swiftRuntimePkgReceipt" > /dev/null; then
        return
    fi

    echo "Host requires Swift 5 Runtime Support installation"

    # In the event Apple breaks the URL, we have an archive.org rehost:
    # https://archive.org/details/swift-runtime-for-command-line-tools_202411
    local runtimeUrl="https://updates.cdn-apple.com/2019/cert/061-41823-20191025-5efc5a59-d7dc-46d3-9096-396bb8cb4a73/SwiftRuntimeForCommandLineTools.dmg"

    local tempDir
    tempDir=$(/usr/bin/mktemp -d -t swift-runtime)

    local runtimeDmg
    runtimeDmg="$tempDir/SwiftRuntimeForCommandLineTools.dmg"

    /usr/bin/curl -L -o "$runtimeDmg" "$runtimeUrl"

    if [[ ! -f "$runtimeDmg" ]]; then
        echo "Failed to download Swift runtime"
        exit 1
    fi

    local mountPoint
    mountPoint=$(/usr/bin/mktemp -d -t swift-runtime-mount)

    /usr/bin/hdiutil attach -nobrowse "$runtimeDmg" -mountpoint "$mountPoint"

    local pkgPath
    pkgPath=$(/usr/bin/find "$mountPoint" -name "*.pkg")

    /usr/sbin/installer -pkg "$pkgPath" -target /

    /usr/bin/hdiutil detach "$mountPoint"

    /bin/rm -rf "$tempDir"
    /bin/rm -rf "$mountPoint"

    if /usr/sbin/pkgutil --pkgs | /usr/bin/grep "$swiftRuntimePkgReceipt" > /dev/null; then
        echo "Swift runtime installed successfully"
        return
    fi

    echo "Failed to install Swift runtime"
    exit 1
}


# Load launch agent/daemon service file
# Arguments:
#  $1: Launch service file
function loadLaunchServiceFile {
    local launchServiceFile="$1"

    local currentUser
    local uid

    currentUser=$(echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }')
    uid=$(/usr/bin/id -u "${currentUser}")

    if [[ "$launchServiceFile" == *"/Library/LaunchAgents"* ]]; then
        /bin/launchctl bootstrap gui/"$uid" "$launchServiceFile" || true
        return
    fi

    /bin/launchctl load "$launchServiceFile" || true
}


# Load all launch agent service files
function loadLaunchServiceFiles {
    local launchServiceFiles

    launchServiceFiles=$(/bin/ls -1 /Library/LaunchDaemons | /usr/bin/grep "$launchServicePrefix")

    for launchServiceFile in $launchServiceFiles; do
        echo "Loading launch service file: $launchServiceFile"
        loadLaunchServiceFile "/Library/LaunchDaemons/$launchServiceFile"
    done

    launchServiceFiles=$(/bin/ls -1 /Library/LaunchAgents | /usr/bin/grep "$launchServicePrefix")

    for launchServiceFile in $launchServiceFiles; do
        echo "Loading launch service file: $launchServiceFile"
        loadLaunchServiceFile "/Library/LaunchAgents/$launchServiceFile"
    done
}


# Main function
function main {
    echo "Loading new installation"
    installSwiftRuntimeSupport
    loadLaunchServiceFiles
}


# MARK: Main
# -----------------------------------------------
main
