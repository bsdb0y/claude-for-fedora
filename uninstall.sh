#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

echo "Uninstalling Claude Desktop..."

# Remove RPM package
if rpm -qa | grep -q claude-desktop; then
    echo "Removing RPM package..."
    dnf remove -y claude-desktop || rpm -e claude-desktop
else
    echo "Claude Desktop RPM not installed"
fi

# Remove files manually in case RPM uninstall missed something
echo "Removing remaining files..."
rm -rf /usr/lib64/claude-desktop
rm -f /usr/bin/claude-desktop
rm -f /usr/share/applications/claude-desktop.desktop
rm -rf /usr/share/icons/hicolor/*/apps/claude-desktop.png

# Update icon and desktop caches
echo "Updating system caches..."
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

# Remove user config (optional - ask first)
read -p "Remove user configuration and logs? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -n "$SUDO_USER" ]; then
        ORIGINAL_HOME=$(eval echo ~$SUDO_USER)
        echo "Removing config from $ORIGINAL_HOME..."
        rm -rf "$ORIGINAL_HOME/.config/Claude"
        rm -f "$ORIGINAL_HOME/.claude-desktop.log"
        rm -f "$ORIGINAL_HOME/claude-desktop-launcher.log"
    else
        echo "Warning: Could not determine user home directory"
    fi
fi

# Remove build directory
read -p "Remove build directory? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$(pwd)/build"
    rm -rf "$(pwd)/claude-build"
    echo "Build directory removed"
fi

echo "Claude Desktop uninstalled successfully"
