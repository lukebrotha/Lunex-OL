#!/usr/bin/env bash
# ==============================================================================
# Lunex Linux Installer, Updater & Uninstaller
# ==============================================================================

# User Directories and Files
INSTALL_DIR="$HOME/.local/share/lunex"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons"
STATE_FILE="$INSTALL_DIR/.wine_installed_by_script"

EXE_URL="https://playlunex.xyz/api/clients/windows/download"
ICON_URL="https://playlunex.xyz/favicon.ico" # Fallback for site logo/icon

EXE_PATH="$INSTALL_DIR/Lunex.exe"
ICON_PATH="$ICON_DIR/lunex.png"
DESKTOP_PATH="$DESKTOP_DIR/lunex.desktop"
LAUNCHER_PATH="$BIN_DIR/lunex"

# ------------------------------------------------------------------------------
# UNINSTALL MODE: Executed if 'export REMOVE=1' or 'REMOVE=1 ./lunex.sh'
# ------------------------------------------------------------------------------
if [ "${REMOVE:-0}" -eq 1 ] || [ "${remove:-0}" -eq 1 ]; then
    echo "[+] Removing Lunex from the system..."

    # 1. Remove created files and shortcuts
    rm -rf "$INSTALL_DIR"
    rm -f "$DESKTOP_PATH"
    rm -f "$ICON_PATH"
    rm -f "$LAUNCHER_PATH"

    # 2. If Wine was installed EXCLUSIVELY by this script, remove it
    if [ -f "$STATE_FILE" ]; then
        echo "[+] Removing Wine (installed previously by the script)..."
        if command -v pacman &>/dev/null; then
            sudo pacman -Rns --noconfirm wine || true
        elif command -v apt-get &>/dev/null; then
            sudo apt-get remove -y wine || true
        elif command -v dnf &>/dev/null; then
            sudo dnf remove -y wine || true
        elif command -v zypper &>/dev/null; then
            sudo zypper remove -y wine || true
        fi
        rm -f "$STATE_FILE"
    else
        echo "[*] Wine kept on system (already existed or was manually installed)."
    fi

    # Update desktop database
    update-desktop-database "$DESKTOP_DIR" &>/dev/null || true

    echo "[✔] Lunex successfully removed!"
    exit 0
fi

# ------------------------------------------------------------------------------
# INSTALLATION / UPDATE MODE
# ------------------------------------------------------------------------------

# Create required local user directories
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"

# 1. Check and Install Wine (if not present)
if ! command -v wine &>/dev/null; then
    echo "[+] Wine not found. Detecting package manager to install..."
    touch "$STATE_FILE" # Mark that the script installed Wine

    if command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm wine
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y wine
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y wine
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y wine
    else
        echo "[!] Error: No supported package manager found (pacman, apt, dnf, zypper)."
        exit 1
    fi
else
    echo "[*] Wine is already installed on the system."
fi

# 2. Download / Auto-Update Lunex.exe
echo "[+] Downloading/Updating Lunex executable..."
curl -sSL "$EXE_URL" -o "$EXE_PATH.tmp"

# Replace old executable if the download completed successfully
if [ -s "$EXE_PATH.tmp" ]; then
    mv "$EXE_PATH.tmp" "$EXE_PATH"
    echo "[✔] Lunex.exe successfully updated."
else
    echo "[!] Download failed. Keeping existing version if available."
    rm -f "$EXE_PATH.tmp"
fi

# 3. Download Icon
if [ ! -f "$ICON_PATH" ]; then
    echo "[+] Downloading site icon..."
    curl -sSL "$ICON_URL" -o "$ICON_PATH" || touch "$ICON_PATH"
fi

# 4. Create Executable Launcher Script ($HOME/.local/bin/lunex)
cat << 'EOF' > "$LAUNCHER_PATH"
#!/usr/bin/env bash
INSTALL_DIR="$HOME/.local/share/lunex"
EXE_PATH="$INSTALL_DIR/Lunex.exe"

if [ -f "$EXE_PATH" ]; then
    wine "$EXE_PATH" "$@"
else
    echo "Lunex executable not found. Please run the install script again."
fi
EOF
chmod +x "$LAUNCHER_PATH"

# 5. Create .desktop file (Application Shortcut)
cat << EOF > "$DESKTOP_PATH"
[Desktop Entry]
Name=Lunex
Comment=Play Lunex Roblox Alternative
Exec=wine "$EXE_PATH"
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Game;
Keywords=roblox;lunex;game;
StartupWMClass=Lunex.exe
EOF

chmod +x "$DESKTOP_PATH"
update-desktop-database "$DESKTOP_DIR" &>/dev/null || true

echo "----------------------------------------------------------------------"
echo "[✔] Installation/Update completed successfully!"
echo "[*] Shortcut created in your system application menu."
echo "[*] To run from terminal, simply type: lunex"
echo "----------------------------------------------------------------------"
