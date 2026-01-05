#!/bin/bash
set -e

# Claude Desktop installer for Fedora Linux
# Extracts Windows installer and repackages for Linux using Electron

CLAUDE_DOWNLOAD_URL="https://downloads.claude.ai/releases/win32/x64/1.0.2339/Claude-1782e27bb4481b2865073bfb82a97b5b23554636.exe"

if [ ! -f "/etc/fedora-release" ]; then
    echo "Error: This script requires Fedora Linux"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run with sudo"
    exit 1
fi

# Preserve original user context
if [ -n "$SUDO_USER" ]; then
    ORIGINAL_USER="$SUDO_USER"
    ORIGINAL_HOME=$(eval echo ~$ORIGINAL_USER)
else
    ORIGINAL_USER="root"
    ORIGINAL_HOME="/root"
fi

echo "Running as: $ORIGINAL_USER"

# Preserve NVM if it exists
if [ "$ORIGINAL_USER" != "root" ] && [ -d "$ORIGINAL_HOME/.nvm" ]; then
    export NVM_DIR="$ORIGINAL_HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    
    NODE_BIN_PATH=$(find "$NVM_DIR/versions/node" -maxdepth 2 -type d -name 'bin' 2>/dev/null | sort -V | tail -n 1)
    if [ -n "$NODE_BIN_PATH" ]; then
        export PATH="$NODE_BIN_PATH:$PATH"
        echo "Using NVM Node from: $NODE_BIN_PATH"
    fi
fi

# Install system dependencies
echo "Installing dependencies..."
DEPS="sqlite p7zip p7zip-plugins wget icoutils ImageMagick nodejs npm rpm-build rpmdevtools curl"
dnf install -y $DEPS

# Install npm packages globally
echo "Installing electron and asar..."
if [ "$ORIGINAL_USER" != "root" ]; then
    sudo -u "$ORIGINAL_USER" npm install -g electron asar 2>/dev/null || npm install -g electron asar
else
    npm install -g electron asar
fi

# Setup build directories
PACKAGE_NAME="claude-desktop"
ARCHITECTURE=$(uname -m)
DISTRIBUTION=$(rpm --eval %{?dist})
WORK_DIR="$(pwd)/claude-build"
FEDORA_ROOT="$WORK_DIR/fedora-package"
INSTALL_DIR="$FEDORA_ROOT/usr"

echo "Setting up build directories..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
mkdir -p "$INSTALL_DIR/lib/$PACKAGE_NAME"
mkdir -p "$INSTALL_DIR/share/applications"
mkdir -p "$INSTALL_DIR/share/icons"
mkdir -p "$INSTALL_DIR/bin"

# Download Claude installer
echo "Downloading Claude Desktop..."
CLAUDE_EXE="$WORK_DIR/Claude-Setup-x64.exe"
if [ ! -f "$CLAUDE_EXE" ]; then
    curl -L -o "$CLAUDE_EXE" "$CLAUDE_DOWNLOAD_URL" --progress-bar
fi

# Extract installer
echo "Extracting installer..."
cd "$WORK_DIR"
7z x -y "$CLAUDE_EXE" > /dev/null 2>&1

# Find and extract nupkg
NUPKG_FILE=$(find . -name "AnthropicClaude-*-full.nupkg" | head -1)
if [ -z "$NUPKG_FILE" ]; then
    echo "Error: Could not find AnthropicClaude nupkg file"
    exit 1
fi

VERSION=$(echo "$NUPKG_FILE" | grep -oP 'AnthropicClaude-\K[0-9]+\.[0-9]+\.[0-9]+(?=-full\.nupkg)')
echo "Claude version: $VERSION"

7z x -y "$NUPKG_FILE" > /dev/null 2>&1

# Extract and install icons
echo "Processing icons..."
wrestool -x -t 14 "lib/net45/claude.exe" -o claude.ico 2>/dev/null
icotool -x claude.ico > /dev/null 2>&1

declare -A icon_files=(
    ["16"]="claude_13_16x16x32.png"
    ["24"]="claude_11_24x24x32.png"
    ["32"]="claude_10_32x32x32.png"
    ["48"]="claude_8_48x48x32.png"
    ["64"]="claude_7_64x64x32.png"
    ["256"]="claude_6_256x256x32.png"
)

for size in 16 24 32 48 64 256; do
    icon_dir="$INSTALL_DIR/share/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    if [ -f "${icon_files[$size]}" ]; then
        install -Dm 644 "${icon_files[$size]}" "$icon_dir/claude-desktop.png"
    fi
done

# Process app.asar
echo "Building application..."
mkdir -p electron-app
cp "lib/net45/resources/app.asar" electron-app/
cp -r "lib/net45/resources/app.asar.unpacked" electron-app/ 2>/dev/null || true

cd electron-app
asar extract app.asar app.asar.contents

# Patch for Linux
sed -i 's/height:e\.height,titleBarStyle:"default",titleBarOverlay:[^,]\+,/height:e.height,frame:true,/g' \
    app.asar.contents/.vite/build/index.js 2>/dev/null || true

# Create stub native module
mkdir -p app.asar.contents/node_modules/claude-native
cp "$WORK_DIR/../templates/claude-native-stub.js" \
   app.asar.contents/node_modules/claude-native/index.js

# Copy resources
cp ../lib/net45/resources/Tray* app.asar.contents/resources/ 2>/dev/null || true
mkdir -p app.asar.contents/resources/i18n/
cp ../lib/net45/resources/*.json app.asar.contents/resources/i18n/ 2>/dev/null || true

# Download UI fixes
cd app.asar.contents
wget -q -O- https://github.com/emsi/claude-desktop/raw/refs/heads/main/assets/main_window.tgz | tar -zxf - 2>/dev/null || true
cd ..

# Repackage
echo "Repackaging application..."
asar pack app.asar.contents app.asar

# Install files
cp app.asar "$INSTALL_DIR/lib/$PACKAGE_NAME/"
cp -r app.asar.unpacked "$INSTALL_DIR/lib/$PACKAGE_NAME/" 2>/dev/null || true

mkdir -p "$INSTALL_DIR/lib/$PACKAGE_NAME/app.asar.unpacked/node_modules/claude-native"
cp app.asar.contents/node_modules/claude-native/index.js \
   "$INSTALL_DIR/lib/$PACKAGE_NAME/app.asar.unpacked/node_modules/claude-native/"

# Create desktop entry
cp "$WORK_DIR/../templates/claude-desktop.desktop" \
   "$INSTALL_DIR/share/applications/"

# Create launcher script
cp "$WORK_DIR/../templates/claude-desktop-launcher.sh" \
   "$INSTALL_DIR/bin/claude-desktop"
chmod +x "$INSTALL_DIR/bin/claude-desktop"

# Build RPM
echo "Building RPM package..."
cd "$WORK_DIR"

# Generate spec file from template
sed -e "s/@VERSION@/$VERSION/g" \
    -e "s/@ARCHITECTURE@/$ARCHITECTURE/g" \
    -e "s/@DISTRIBUTION@/$DISTRIBUTION/g" \
    -e "s|@INSTALL_DIR@|$INSTALL_DIR|g" \
    "$WORK_DIR/../templates/claude-desktop.spec.template" > claude-desktop.spec

mkdir -p BUILD RPMS SOURCES SPECS SRPMS

RPM_FILE="$(pwd)/${ARCHITECTURE}/claude-desktop-${VERSION}-1${DISTRIBUTION}.${ARCHITECTURE}.rpm"

rpmbuild -bb \
    --define "_topdir ${WORK_DIR}" \
    --define "_rpmdir $(pwd)" \
    claude-desktop.spec

echo ""
echo "RPM package built: $RPM_FILE"
echo ""
echo "Install with: sudo rpm -ivh --nodeps $RPM_FILE"
echo "Run with: claude-desktop"
