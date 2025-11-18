#!/bin/bash

# Smart WiFi Controller - Reinstall/Update Script
# Updates an existing installation with the latest version
# Usage: ./reinstall.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${1:-/opt/smart-wifi-controller}"
SERVICE_NAME="smart-wifi-controller"
SERVICE_FILE="/etc/systemd/system/smart-wifi-controller.service"

# Script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_banner() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║          Smart WiFi Controller - REINSTALL/UPDATE             ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Dieses Script benötigt Root-Rechte"
        echo "Bitte ausführen mit: sudo ./reinstall.sh"
        exit 1
    fi
}

# Check if already installed
check_installation() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_warn "Installationsverzeichnis nicht gefunden: $INSTALL_DIR"
        log_info "Starte Neuinstallation statt Update..."
        return 1
    fi

    if ! command -v "$SERVICE_NAME" &> /dev/null; then
        log_warn "Installation inkonsistent - Kommando nicht im PATH"
        return 1
    fi

    return 0
}

# Stop the daemon
stop_daemon() {
    log_info "Stoppe Smart WiFi Controller Daemon..."

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        log_success "Daemon gestoppt"
        return 0
    elif pgrep -f "smart_wifi_daemon.sh" > /dev/null 2>&1; then
        pkill -f "smart_wifi_daemon.sh" || true
        log_success "Daemon-Prozess beendet"
        return 0
    else
        log_info "Daemon war nicht aktiv"
        return 0
    fi
}

# Check and install dependencies
check_dependencies() {
    log_info "Überprüfe Systemabhängigkeiten..."

    local missing_tools=()

    # Check for NetworkManager
    if ! command -v nmcli &> /dev/null; then
        missing_tools+=("network-manager")
        log_warn "NetworkManager nicht gefunden"
    else
        log_success "NetworkManager verfügbar"
    fi

    # Check for GUI tools
    if ! command -v zenity &> /dev/null && ! command -v kdialog &> /dev/null; then
        missing_tools+=("zenity")
        log_warn "Kein GUI-Toolkit gefunden"
    else
        [ -n "$(command -v zenity)" ] && log_success "Zenity verfügbar"
        [ -n "$(command -v kdialog)" ] && log_success "KDialog verfügbar"
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_info "Installiere fehlende Abhängigkeiten: ${missing_tools[*]}"

        if command -v apt &> /dev/null; then
            apt update
            apt install -y "${missing_tools[@]}" || true
        elif command -v dnf &> /dev/null; then
            dnf install -y "${missing_tools[@]}" || true
        elif command -v pacman &> /dev/null; then
            pacman -S --noconfirm "${missing_tools[@]}" || true
        else
            log_warn "Paketmanager nicht erkannt - bitte manuell installieren"
        fi
    fi
}

# Copy/update files
update_files() {
    log_info "Aktualisiere Dateien in $INSTALL_DIR..."

    # Create install directory if needed
    mkdir -p "$INSTALL_DIR"

    # Copy main scripts
    local files=(
        "smart_wifi_controller.sh"
        "smart_wifi_core.sh"
        "smart_wifi_daemon.sh"
        "smart_wifi_gui_prompts.sh"
        "smart_wifi_conditions.sh"
        "smart_wifi_rules.conf"
    )

    for file in "${files[@]}"; do
        if [ -f "$SCRIPT_DIR/$file" ]; then
            cp "$SCRIPT_DIR/$file" "$INSTALL_DIR/$file"
            chmod +x "$INSTALL_DIR/$file" 2>/dev/null || true
            log_success "Aktualisiert: $file"
        else
            log_warn "Datei nicht gefunden: $file"
        fi
    done

    # Copy binary to /usr/local/bin
    log_info "Aktualisiere Befehl: /usr/local/bin/smart-wifi-controller"
    cp "$INSTALL_DIR/smart_wifi_controller.sh" /usr/local/bin/smart-wifi-controller
    chmod +x /usr/local/bin/smart-wifi-controller
    log_success "Befehl aktualisiert"
}

# Update systemd service file
update_service() {
    log_info "Aktualisiere systemd Service..."

    if [ ! -f "/etc/systemd/system/smart-wifi-controller.service" ]; then
        log_warn "Service-Datei nicht gefunden - überspringe"
        return 0
    fi

    # Check if we should update the service file
    if [ -f "$SCRIPT_DIR/smart-wifi-controller.service" ]; then
        cp "$SCRIPT_DIR/smart-wifi-controller.service" /etc/systemd/system/smart-wifi-controller.service
        systemctl daemon-reload
        log_success "Service-Datei aktualisiert"
    fi
}

# Start the daemon again
start_daemon() {
    log_info "Starte Smart WiFi Controller Daemon..."

    if [ -f "/etc/systemd/system/smart-wifi-controller.service" ]; then
        systemctl start "$SERVICE_NAME"
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            log_success "Daemon erfolgreich gestartet"
        else
            log_error "Daemon konnte nicht gestartet werden"
            return 1
        fi
    else
        log_warn "Systemd-Service nicht installiert - starte Daemon manuell nicht"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifiziere Installation..."

    local errors=0

    # Check files exist
    for file in smart_wifi_controller.sh smart_wifi_core.sh smart_wifi_daemon.sh; do
        if [ ! -f "$INSTALL_DIR/$file" ]; then
            log_error "Datei fehlt: $file"
            ((errors++))
        else
            log_success "$file vorhanden"
        fi
    done

    # Check command
    if ! command -v smart-wifi-controller &> /dev/null; then
        log_error "Befehl 'smart-wifi-controller' nicht verfügbar"
        ((errors++))
    else
        log_success "Befehl 'smart-wifi-controller' verfügbar"
    fi

    # Check daemon status
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        log_success "Daemon läuft"
    else
        log_warn "Daemon läuft nicht (optional)"
    fi

    return $errors
}

# Show summary
show_summary() {
    cat << EOF

╔════════════════════════════════════════════════════════════════╗
║                   UPDATE ERFOLGREICH ✓                        ║
╚════════════════════════════════════════════════════════════════╝

📍 Installationsverzeichnis: $INSTALL_DIR
🔧 Befehl:                   smart-wifi-controller
📋 Service:                  systemctl status smart-wifi-controller
📊 Log:                      systemctl -u smart-wifi-controller -f

Nächste Schritte:
  1. Status überprüfen:      systemctl status smart-wifi-controller
  2. Daemon neustarten:      systemctl restart smart-wifi-controller
  3. Logs ansehen:           journalctl -u smart-wifi-controller -f

Weitere Befehle:
  smart-wifi-controller --help       Hilfe anzeigen
  smart-wifi-controller --status     Status anzeigen
  smart-wifi-controller --log        Log-Einträge

EOF
}

# Main execution
main() {
    show_banner
    check_root

    log_info "Starte Smart WiFi Controller Update/Reinstall..."
    echo ""

    # Check if already installed
    if check_installation; then
        log_info "Existierende Installation gefunden"
        stop_daemon
    else
        log_info "Keine Installation gefunden - führe Neuinstallation durch"
    fi

    echo ""
    check_dependencies
    echo ""
    update_files
    echo ""
    update_service
    echo ""
    start_daemon
    echo ""

    if verify_installation; then
        show_summary
        exit 0
    else
        log_error "Einige Dateien konnten nicht überprüft werden"
        show_summary
        exit 1
    fi
}

# Run main function
main "$@"
