#!/bin/bash

# Installation Script für Smart WiFi Controller
# Installiert das Smart WiFi Controller Script systemweit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_NAME="smart_wifi_controller.sh"
INSTALLED_NAME="smart-wifi-controller"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Smart WiFi Controller Installation${NC}"
echo "===================================="

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

# Copy and install core logic library
echo "Kopiere Core-Logik nach $INSTALL_DIR/smart_wifi_core.sh..."
if cp "$SCRIPT_DIR/smart_wifi_core.sh" "$INSTALL_DIR/smart_wifi_core.sh"; then
    chmod +x "$INSTALL_DIR/smart_wifi_core.sh"
    echo -e "${GREEN}✓ Core-Logik erfolgreich installiert${NC}"
else
    echo -e "${RED}✗ Fehler beim Kopieren der Core-Logik${NC}"
    exit 1
fi

# Copy and install GUI prompts script
echo "Kopiere GUI-Prompts nach $INSTALL_DIR/smart_wifi_gui_prompts.sh..."
if cp "$SCRIPT_DIR/smart_wifi_gui_prompts.sh" "$INSTALL_DIR/smart_wifi_gui_prompts.sh"; then
    chmod +x "$INSTALL_DIR/smart_wifi_gui_prompts.sh"
    echo -e "${GREEN}✓ GUI-Prompts erfolgreich installiert${NC}"
else
    echo -e "${RED}✗ Fehler beim Kopieren der GUI-Prompts${NC}"
    exit 1
fi

# Copy and install conditions evaluation engine
echo "Kopiere Conditions-Engine nach $INSTALL_DIR/smart_wifi_conditions.sh..."
if cp "$SCRIPT_DIR/smart_wifi_conditions.sh" "$INSTALL_DIR/smart_wifi_conditions.sh"; then
    chmod +x "$INSTALL_DIR/smart_wifi_conditions.sh"
    echo -e "${GREEN}✓ Conditions-Engine erfolgreich installiert${NC}"
else
    echo -e "${RED}✗ Fehler beim Kopieren der Conditions-Engine${NC}"
    exit 1
fi

# Copy and install daemon script
echo "Kopiere Daemon-Script nach $INSTALL_DIR/smart_wifi_daemon..."
if cp "$SCRIPT_DIR/smart_wifi_daemon.sh" "$INSTALL_DIR/smart_wifi_daemon"; then
    chmod +x "$INSTALL_DIR/smart_wifi_daemon"
    echo -e "${GREEN}✓ Daemon-Script erfolgreich installiert${NC}"
else
    echo -e "${RED}✗ Fehler beim Kopieren des Daemon-Scripts${NC}"
    exit 1
fi

# Copy rules configuration
echo "Kopiere Regeln-Konfiguration nach $INSTALL_DIR/smart_wifi_rules.conf..."
if cp "$SCRIPT_DIR/smart_wifi_rules.conf" "$INSTALL_DIR/smart_wifi_rules.conf"; then
    chmod +x "$INSTALL_DIR/smart_wifi_rules.conf"
    echo -e "${GREEN}✓ Regeln-Konfiguration erfolgreich installiert${NC}"
else
    echo -e "${RED}✗ Fehler beim Kopieren der Regeln-Konfiguration${NC}"
    exit 1
fi

# Install systemd service (user-level)
echo "Installiere Systemd Service..."
SYSTEMD_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_DIR"
if cp "$SCRIPT_DIR/smart-wifi-controller.service" "$SYSTEMD_DIR/smart-wifi-controller.service"; then
    # Update the service file to use correct paths
    sed -i "s|%u|$USER|g" "$SYSTEMD_DIR/smart-wifi-controller.service"
    sed -i "s|%U|$(id -u)|g" "$SYSTEMD_DIR/smart-wifi-controller.service"
    sed -i "s|%h|$HOME|g" "$SYSTEMD_DIR/smart-wifi-controller.service"

    # Reload systemd daemon
    systemctl --user daemon-reload
    echo -e "${GREEN}✓ Systemd Service installiert${NC}"
else
    echo -e "${YELLOW}⚠ Systemd Service konnte nicht installiert werden${NC}"
fi

# Create desktop entry
echo "Erstelle Desktop-Entry..."
cat > "$DESKTOP_DIR/smart-wifi-controller.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Smart WiFi Controller
Name[de]=Smart WiFi Controller
Comment=Manage WiFi and Ethernet connections intelligently
Comment[de]=WiFi und Ethernet-Verbindungen intelligent verwalten
Exec=$INSTALL_DIR/$INSTALLED_NAME
Icon=network-wired
Terminal=false
Categories=Network;Settings;
Keywords=network;wifi;ethernet;connection;smart;
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

# Check for Python3 and AppIndicator3 (für System Tray)
if ! command -v python3 &> /dev/null; then
    missing_deps+=("python3")
fi

# Check for AppIndicator3 Python package
python3 -c "import gi; gi.require_version('AppIndicator3', '0.1')" 2>/dev/null
if [ $? -ne 0 ]; then
    missing_deps+=("libappindicator3-1 (für System Tray Icon)")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${YELLOW}⚠ Fehlende Abhängigkeiten:${NC}"
    for dep in "${missing_deps[@]}"; do
        echo "  - $dep"
    done
    echo ""
    echo "Installation unter Ubuntu/Debian:"
    echo "sudo apt update && sudo apt install network-manager zenity python3 libappindicator3-1 gir1.2-appindicator3-0.1"
    echo ""
    echo "Installation unter Fedora/RHEL:"
    echo "sudo dnf install NetworkManager zenity python3 libappindicator-gtk3"
else
    echo -e "${GREEN}✓ Alle Abhängigkeiten sind installiert${NC}"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Installation erfolgreich abgeschlossen! ✓              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Installierte Dateien:${NC}"
echo "  ✓ smart-wifi-controller (Hauptskript)"
echo "  ✓ smart_wifi_core.sh (Core-Logik)"
echo "  ✓ smart_wifi_gui_prompts.sh (GUI mit Countdown-Dialog)"
echo "  ✓ smart_wifi_conditions.sh (Condition-Engine)"
echo "  ✓ smart_wifi_daemon.sh (Daemon)"
echo "  ✓ smart_wifi_rules.conf (Regelkonfiguration)"
echo ""
echo -e "${GREEN}Verwendung:${NC}"
echo "  - GUI starten: $INSTALLED_NAME"
echo "  - Status anzeigen: $INSTALLED_NAME --status"
echo "  - Daemon starten: systemctl --user start smart-wifi-controller"
echo "  - Daemon aktivieren (beim Hochfahren): systemctl --user enable smart-wifi-controller"
echo "  - Daemon stoppen: systemctl --user stop smart-wifi-controller"
echo "  - Daemon Status: systemctl --user status smart-wifi-controller"
echo "  - Update durchführen: sudo ./reinstall.sh"
echo "  - Hilfe: $INSTALLED_NAME --help"
echo ""

if [ "$INSTALL_TYPE" = "user" ]; then
    echo -e "${YELLOW}Hinweis:${NC} Stellen Sie sicher, dass ~/.local/bin in Ihrem PATH ist:"
    echo "echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "source ~/.bashrc"
fi

echo ""
echo -e "${GREEN}Daemon-Setup:${NC}"
echo "Um den Daemon beim Hochfahren automatisch zu starten:"
echo "  systemctl --user enable smart-wifi-controller"
echo ""
echo "Um den Daemon jetzt zu starten:"
echo "  systemctl --user start smart-wifi-controller"
echo ""
echo "Das Script kann auch über das Anwendungsmenü gefunden werden (Smart WiFi Controller)."