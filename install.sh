#!/bin/bash

# Installation Script für Network Manager
# Installiert das Network Manager Script systemweit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_NAME="network_manager.sh"
INSTALLED_NAME="network-manager"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Network Manager Installation${NC}"
echo "================================"

# Check if running as root for system installation
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Installation als Root erkannt - systemweite Installation${NC}"
    INSTALL_TYPE="system"
else
    echo -e "${YELLOW}Installation als normaler Benutzer - lokale Installation${NC}"
    INSTALL_DIR="$HOME/.local/bin"
    DESKTOP_DIR="$HOME/.local/share/applications"
    INSTALL_TYPE="user"
fi

# Create directories if they don't exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR"

# Copy the main script
echo "Kopiere Script nach $INSTALL_DIR/$INSTALLED_NAME..."
if cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$INSTALLED_NAME"; then
    chmod +x "$INSTALL_DIR/$INSTALLED_NAME"
    echo -e "${GREEN}✓ Script erfolgreich installiert${NC}"
else
    echo -e "${RED}✗ Fehler beim Kopieren des Scripts${NC}"
    exit 1
fi

# Create desktop entry
echo "Erstelle Desktop-Entry..."
cat > "$DESKTOP_DIR/network-manager.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Network Manager
Name[de]=Netzwerk-Manager
Comment=Manage WiFi and Ethernet connections automatically
Comment[de]=WiFi und Ethernet-Verbindungen automatisch verwalten
Exec=$INSTALL_DIR/$INSTALLED_NAME
Icon=network-wired
Terminal=false
Categories=Network;Settings;
Keywords=network;wifi;ethernet;connection;
StartupNotify=true
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Desktop-Entry erstellt${NC}"
    
    # Update desktop database if available
    if command -v update-desktop-database &> /dev/null; then
        if [ "$INSTALL_TYPE" = "system" ]; then
            update-desktop-database /usr/share/applications
        else
            update-desktop-database "$HOME/.local/share/applications"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Desktop-Entry konnte nicht erstellt werden${NC}"
fi

# Check dependencies
echo ""
echo "Überprüfe Abhängigkeiten..."

missing_deps=()

if ! command -v nmcli &> /dev/null; then
    missing_deps+=("NetworkManager")
fi

if ! command -v zenity &> /dev/null && ! command -v kdialog &> /dev/null; then
    missing_deps+=("zenity oder kdialog")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${YELLOW}⚠ Fehlende Abhängigkeiten:${NC}"
    for dep in "${missing_deps[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Installation unter Ubuntu/Debian:"
    echo "sudo apt update && sudo apt install network-manager zenity"
    echo ""
    echo "Installation unter Fedora/RHEL:"
    echo "sudo dnf install NetworkManager zenity"
else
    echo -e "${GREEN}✓ Alle Abhängigkeiten sind installiert${NC}"
fi

echo ""
echo -e "${GREEN}Installation abgeschlossen!${NC}"
echo ""
echo "Verwendung:"
echo "  - GUI starten: $INSTALLED_NAME"
echo "  - Status anzeigen: $INSTALLED_NAME --status"
echo "  - Automatisierung aktivieren: $INSTALLED_NAME --enable-auto"
echo "  - Hilfe: $INSTALLED_NAME --help"
echo ""

if [ "$INSTALL_TYPE" = "user" ]; then
    echo -e "${YELLOW}Hinweis:${NC} Stellen Sie sicher, dass ~/.local/bin in Ihrem PATH ist:"
    echo "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "source ~/.bashrc"
fi

echo ""
echo "Das Script kann auch über das Anwendungsmenü gefunden werden (Network Manager)."