#!/bin/bash

# Smart WiFi Controller - Installation/Reinstall Script
# Installiert oder aktualisiert die Installation
# - Erkennt existierende Installation automatisch
# - Fragt nach Daemon-Installation bei Neuinstallation
# - Führt automatisches Update durch bei existierender Installation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
DESKTOP_DIR="/usr/share/applications"
SCRIPT_NAME="smart_wifi_controller.sh"
INSTALLED_NAME="smart-wifi-controller"
DEFAULT_LOG_DIR="$HOME/.local/share/smart_wifi_controller"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root for system installation
if [ "$EUID" -eq 0 ]; then
    INSTALL_TYPE="system"
    INSTALL_DIR="/usr/local/bin"
    DESKTOP_DIR="/usr/share/applications"
else
    INSTALL_TYPE="user"
    INSTALL_DIR="$HOME/.local/bin"
    DESKTOP_DIR="$HOME/.local/share/applications"
fi

# Check if already installed
check_installation() {
    if command -v "$INSTALLED_NAME" &> /dev/null; then
        return 0  # Already installed
    else
        return 1  # Not installed
    fi
}

# Show banner
show_banner() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║          Smart WiFi Controller - Installation/Update          ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
}

show_banner
echo ""

# Show current status
echo -e "${BLUE}═══ SYSTEMSTATUS ═══${NC}"
echo ""

# Check installation status
if check_installation; then
    echo -e "Status:        ${GREEN}✓ INSTALLIERT${NC}"

    # Check daemon status
    daemon_installed=false
    if systemctl is-enabled --quiet smart-wifi-controller 2>/dev/null; then
        daemon_installed=true
        if systemctl is-active --quiet smart-wifi-controller 2>/dev/null; then
            echo -e "Dienst:        ${GREEN}✓ AKTIV (läuft)${NC}"
        else
            echo -e "Dienst:        ${YELLOW}⚠ INSTALLIERT (gestoppt)${NC}"
        fi
    else
        echo -e "Dienst:        ${YELLOW}✗ NICHT INSTALLIERT${NC}"
    fi

    # Check command location
    cmd_path=$(command -v "$INSTALLED_NAME" 2>/dev/null)
    echo -e "Installiert:   $cmd_path"
else
    echo -e "Status:        ${RED}✗ NICHT INSTALLIERT${NC}"
    echo -e "Dienst:        ${RED}✗ NICHT INSTALLIERT${NC}"
    daemon_installed=false
fi

echo ""
echo -e "${BLUE}═══ OPTIONEN ═══${NC}"
echo ""

if check_installation; then
    echo "  [I] Installation überprüfen"
    echo "  [R] Update durchführen"
    if [ "$daemon_installed" = false ]; then
        echo "  [S] Dienst installieren"
    else
        echo "  [S] Dienst verwalten"
    fi
    echo "  [D] Deinstallieren"
    echo ""
    read -p "Wähle Option (I/R/S/D): " option
    option=$(echo "$option" | tr '[:lower:]' '[:upper:]')

    case "$option" in
        I)
            echo "✓ Überprüfe Installation..."
            INSTALL_TYPE="verify"
            ;;
        R)
            echo "✓ Starte Update..."
            INSTALL_TYPE="update"
            INSTALL_DAEMON=false
            ;;
        S)
            echo "✓ Installiere/Verwalte Dienst..."
            INSTALL_TYPE="service_install"
            INSTALL_DAEMON=true
            ;;
        D)
            echo ""
            echo -e "${RED}VORSICHT: Dies wird Smart WiFi Controller vollständig entfernen!${NC}"
            read -p "Wirklich deinstallieren? (ja/nein): " confirm
            if [ "$confirm" = "ja" ]; then
                INSTALL_TYPE="uninstall"
            else
                echo "Abgebrochen."
                exit 0
            fi
            ;;
        *)
            echo -e "${RED}Ungültige Option${NC}"
            exit 1
            ;;
    esac
else
    echo "  [I] Installieren"
    echo "  [D] Deinstallieren"
    echo ""
    read -p "Wähle Option (I/D): " option
    option=$(echo "$option" | tr '[:lower:]' '[:upper:]')

    case "$option" in
        I)
            echo "✓ Starte Installation..."
            INSTALL_TYPE="install"

            # Check dependencies first
            echo ""
            echo -e "${BLUE}═══ ABHÄNGIGKEITSPRÜFUNG ═══${NC}"
            echo ""

            missing_deps=()

            # Check for NetworkManager
            if command -v nmcli &> /dev/null; then
                echo -e "${GREEN}✓${NC} NetworkManager"
            else
                echo -e "${RED}✗${NC} NetworkManager (FEHLT)"
                missing_deps+=("network-manager")
            fi

            # Check for GUI tools
            if command -v zenity &> /dev/null; then
                echo -e "${GREEN}✓${NC} Zenity (GUI)"
            elif command -v kdialog &> /dev/null; then
                echo -e "${GREEN}✓${NC} KDialog (GUI)"
            else
                echo -e "${RED}✗${NC} zenity oder kdialog (FEHLT)"
                missing_deps+=("zenity")
            fi

            echo ""

            # Ask if daemon should be installed
            echo "Soll der Smart WiFi Controller Daemon installiert werden?"
            echo "(Der Daemon überwacht Ethernet/WiFi kontinuierlich im Hintergrund)"
            echo ""
            read -p "Dienst installieren? (j/n) [Standard: j]: " daemon_choice
            daemon_choice=${daemon_choice:-j}

            if [[ "$daemon_choice" =~ ^[Jj] ]]; then
                INSTALL_DAEMON=true
                echo "✓ Dienst wird installiert"
            else
                INSTALL_DAEMON=false
                echo "✓ Dienst wird nicht installiert"
            fi
            echo ""

            # Ask for log location
            read -p "Log-Verzeichnis [Standard: $DEFAULT_LOG_DIR]: " log_dir
            log_dir=${log_dir:-$DEFAULT_LOG_DIR}
            echo "✓ Log-Verzeichnis: $log_dir"
            ;;
        D)
            echo -e "${RED}VORSICHT: Smart WiFi Controller ist nicht installiert!${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}Ungültige Option${NC}"
            exit 1
            ;;
    esac
fi

echo ""

# Handle service installation only
if [ "$INSTALL_TYPE" = "service_install" ]; then
    echo "Installiere/Verwalte Dienst..."
    echo ""

    SYSTEMD_DIR="/etc/systemd/system"
    mkdir -p "$SYSTEMD_DIR"

    echo "Kopiere Service-Datei nach $SYSTEMD_DIR..."
    if cp "$SCRIPT_DIR/smart-wifi-controller.service" "$SYSTEMD_DIR/smart-wifi-controller.service"; then
        # Ensure permissions are correct
        chmod 644 "$SYSTEMD_DIR/smart-wifi-controller.service"

        # Reload systemd daemon
        systemctl daemon-reload
        echo -e "${GREEN}✓${NC} Service-Datei installiert"

        # Start the service
        echo ""
        echo "Starte Dienst..."
        systemctl start smart-wifi-controller

        if systemctl is-active --quiet smart-wifi-controller; then
            echo -e "${GREEN}✓${NC} Dienst erfolgreich gestartet"
        else
            echo -e "${YELLOW}⚠${NC} Dienst konnte nicht gestartet werden"
            echo ""
            echo "Status-Informationen:"
            systemctl status smart-wifi-controller
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Letzte 50 Log-Zeilen:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            journalctl -u smart-wifi-controller -n 50 --no-pager
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            read -p "Erneut versuchen? (j/n): " retry_choice

            if [[ "$retry_choice" =~ ^[Jj] ]]; then
                echo "Starte Dienst erneut..."
                systemctl restart smart-wifi-controller
                sleep 2

                if systemctl is-active --quiet smart-wifi-controller; then
                    echo -e "${GREEN}✓${NC} Dienst erfolgreich gestartet"
                else
                    echo -e "${RED}✗${NC} Dienst konnte immer noch nicht gestartet werden"
                    echo ""
                    echo "Aktuelle Logs:"
                    journalctl -u smart-wifi-controller -n 20 --no-pager
                    echo ""
                    echo "Weitere Informationen:"
                    echo "  systemctl status smart-wifi-controller"
                    echo "  journalctl -u smart-wifi-controller -f   (Live-Logs)"
                fi
            else
                echo "Service-Datei wurde installiert, aber nicht gestartet."
                echo "Sie können den Dienst später manuell starten mit:"
                echo "  systemctl start smart-wifi-controller"
            fi
        fi

        # Ask to enable at startup
        echo ""
        read -p "Dienst beim Hochfahren automatisch starten? (j/n) [Standard: j]: " enable_choice
        enable_choice=${enable_choice:-j}

        if [[ "$enable_choice" =~ ^[Jj] ]]; then
            systemctl enable smart-wifi-controller
            echo -e "${GREEN}✓${NC} Dienst beim Hochfahren aktiviert"
        fi

        echo ""
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║      Dienst erfolgreich installiert! ✓                    ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Verwendung:"
        echo "  systemctl status smart-wifi-controller   # Status anzeigen"
        echo "  systemctl start smart-wifi-controller    # Dienst starten"
        echo "  systemctl stop smart-wifi-controller     # Dienst stoppen"
        echo "  systemctl restart smart-wifi-controller  # Dienst neustarten"
        echo "  journalctl -u smart-wifi-controller -f   # Logs anzeigen"
        echo ""
    else
        echo -e "${RED}✗${NC} Fehler beim Installieren der Service-Datei"
        exit 1
    fi
    exit 0
fi

# Handle uninstall
if [ "$INSTALL_TYPE" = "uninstall" ]; then
    echo "Deinstalliere Smart WiFi Controller..."
    echo ""

    # Stop daemon if running
    if systemctl is-active --quiet smart-wifi-controller 2>/dev/null; then
        systemctl stop smart-wifi-controller
        echo -e "${GREEN}✓${NC} Dienst gestoppt"
    fi

    # Disable daemon
    if systemctl is-enabled --quiet smart-wifi-controller 2>/dev/null; then
        systemctl disable smart-wifi-controller 2>/dev/null
        echo -e "${GREEN}✓${NC} Dienst deaktiviert"
    fi

    # Remove service file
    if [ -f "/etc/systemd/system/smart-wifi-controller.service" ]; then
        rm -f "/etc/systemd/system/smart-wifi-controller.service"
        systemctl daemon-reload
        echo -e "${GREEN}✓${NC} Service-Datei entfernt"
    fi

    # Remove installed files
    rm -f "$INSTALL_DIR/$INSTALLED_NAME"
    rm -f "$INSTALL_DIR/smart_wifi_core.sh"
    rm -f "$INSTALL_DIR/smart_wifi_gui_prompts.sh"
    rm -f "$INSTALL_DIR/smart_wifi_conditions.sh"
    rm -f "$INSTALL_DIR/smart_wifi_daemon"
    rm -f "$INSTALL_DIR/smart_wifi_rules.conf"
    echo -e "${GREEN}✓${NC} Programmdateien entfernt"

    # Remove desktop entry
    rm -f "$DESKTOP_DIR/smart-wifi-controller.desktop"
    echo -e "${GREEN}✓${NC} Desktop-Entry entfernt"

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      Deinstallation erfolgreich abgeschlossen! ✓           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    exit 0
fi

# Skip file copy if only verifying
if [ "$INSTALL_TYPE" = "verify" ]; then
    echo "Verifiziere Installation..."
    echo ""

    errors=0

    # Check files
    echo "Überprüfe Dateien in $INSTALL_DIR:"

    # Main script (installed as smart-wifi-controller)
    if [ -f "$INSTALL_DIR/$INSTALLED_NAME" ]; then
        echo -e "${GREEN}✓${NC} smart-wifi-controller vorhanden"
    else
        echo -e "${RED}✗${NC} smart-wifi-controller FEHLT"
        ((errors++))
    fi

    # Core library
    if [ -f "$INSTALL_DIR/smart_wifi_core.sh" ]; then
        echo -e "${GREEN}✓${NC} smart_wifi_core.sh vorhanden"
    else
        echo -e "${RED}✗${NC} smart_wifi_core.sh FEHLT"
        ((errors++))
    fi

    # GUI prompts
    if [ -f "$INSTALL_DIR/smart_wifi_gui_prompts.sh" ]; then
        echo -e "${GREEN}✓${NC} smart_wifi_gui_prompts.sh vorhanden"
    else
        echo -e "${RED}✗${NC} smart_wifi_gui_prompts.sh FEHLT"
        ((errors++))
    fi

    # Conditions engine
    if [ -f "$INSTALL_DIR/smart_wifi_conditions.sh" ]; then
        echo -e "${GREEN}✓${NC} smart_wifi_conditions.sh vorhanden"
    else
        echo -e "${RED}✗${NC} smart_wifi_conditions.sh FEHLT"
        ((errors++))
    fi

    # Daemon script
    if [ -f "$INSTALL_DIR/smart_wifi_daemon" ] || [ -f "$INSTALL_DIR/smart_wifi_daemon.sh" ]; then
        echo -e "${GREEN}✓${NC} smart_wifi_daemon vorhanden"
    else
        echo -e "${RED}✗${NC} smart_wifi_daemon FEHLT"
        ((errors++))
    fi

    # Check command
    echo ""
    if command -v "$INSTALLED_NAME" &> /dev/null; then
        echo -e "${GREEN}✓${NC} Befehl 'smart-wifi-controller' verfügbar"
    else
        echo -e "${RED}✗${NC} Befehl 'smart-wifi-controller' NICHT verfügbar"
        ((errors++))
    fi

    echo ""
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}✓ Installation ist OK${NC}"
        exit 0
    else
        echo -e "${RED}✗ Installation hat Probleme${NC}"
        exit 1
    fi
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

# Handle daemon installation/update
if [ "$INSTALL_TYPE" = "update" ]; then
    # Stop daemon before updating
    echo "Stoppe Dienst vor Update..."
    if systemctl is-active --quiet smart-wifi-controller 2>/dev/null; then
        systemctl stop smart-wifi-controller
        echo -e "${GREEN}✓ Dienst gestoppt${NC}"
    fi
    echo ""
fi

# Install systemd service only if daemon should be installed
if [ "$INSTALL_DAEMON" = true ] || [ "$INSTALL_TYPE" = "update" ]; then
    echo "Installiere/Aktualisiere Systemd Service..."
    SYSTEMD_DIR="/etc/systemd/system"
    mkdir -p "$SYSTEMD_DIR"

    if cp "$SCRIPT_DIR/smart-wifi-controller.service" "$SYSTEMD_DIR/smart-wifi-controller.service"; then
        # Ensure permissions are correct
        chmod 644 "$SYSTEMD_DIR/smart-wifi-controller.service"

        # Reload systemd daemon
        systemctl daemon-reload
        echo -e "${GREEN}✓ Systemd Service installiert/aktualisiert${NC}"
    else
        echo -e "${YELLOW}⚠ Systemd Service konnte nicht installiert werden${NC}"
    fi
    echo ""
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

# Restart daemon if it was running (update case)
if [ "$INSTALL_TYPE" = "update" ]; then
    echo "Starte Dienst neu..."
    if systemctl is-enabled --quiet smart-wifi-controller 2>/dev/null; then
        systemctl start smart-wifi-controller
        echo -e "${GREEN}✓ Dienst neugestartet${NC}"
    fi
    echo ""
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
if [ "$INSTALL_TYPE" = "update" ]; then
    echo "║         Update erfolgreich abgeschlossen! ✓              ║"
elif [ "$INSTALL_TYPE" = "install" ]; then
    echo "║     Installation erfolgreich abgeschlossen! ✓              ║"
fi
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

if [ -n "$log_dir" ]; then
    echo -e "${GREEN}Log-Verzeichnis:${NC}"
    echo "  📁 $log_dir"
    echo ""
fi

echo -e "${GREEN}Verwendung:${NC}"
echo "  - GUI starten: $INSTALLED_NAME"
echo "  - Status anzeigen: $INSTALLED_NAME --status"

if [ "$INSTALL_DAEMON" = true ] || [ "$INSTALL_TYPE" = "update" ]; then
    echo "  - Dienst starten: systemctl start smart-wifi-controller"
    echo "  - Dienst beim Hochfahren aktivieren: systemctl enable smart-wifi-controller"
    echo "  - Dienst stoppen: systemctl stop smart-wifi-controller"
    echo "  - Dienst Status: systemctl status smart-wifi-controller"
    echo "  - Dienst Logs: journalctl -u smart-wifi-controller -f"
fi
echo "  - Update durchführen: sudo $SCRIPT_DIR/install.sh"
echo "  - Hilfe: $INSTALLED_NAME --help"
echo ""

if [ "$INSTALL_TYPE" != "update" ] && [ "$INSTALL_DIR" = "$HOME/.local/bin" ]; then
    echo -e "${YELLOW}Hinweis:${NC} Stellen Sie sicher, dass ~/.local/bin in Ihrem PATH ist:"
    echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
    echo ""
fi

if [ "$INSTALL_DAEMON" = true ] && [ "$INSTALL_TYPE" = "install" ]; then
    echo -e "${GREEN}Dienst-Setup:${NC}"
    echo "  Um den Dienst beim Hochfahren automatisch zu starten:"
    echo "    systemctl enable smart-wifi-controller"
    echo ""
    echo "  Um den Dienst jetzt zu starten:"
    echo "    systemctl start smart-wifi-controller"
    echo ""
fi

echo "Das Script kann auch über das Anwendungsmenü gefunden werden (Smart WiFi Controller)."
echo ""
echo -e "${BLUE}═══ WEITERE BEFEHLE ═══${NC}"
echo "  smart-wifi-controller               # GUI starten"
echo "  smart-wifi-controller --status      # Status anzeigen"
echo "  systemctl status smart-wifi-controller  # Dienst Status"
echo "  sudo ./install.sh                   # Update/Verwalten"