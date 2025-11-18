#!/bin/bash

# Smart WiFi Controller - Uninstall Script
# Removes all daemon and configuration files for the current user
# Usage: sudo -u julian ./uninstall.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Smart WiFi Controller - Uninstall${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

# Get current user
CURRENT_USER=$(whoami)
USER_HOME=$(eval echo "~$CURRENT_USER")

echo -e "\n${YELLOW}Benutzer: $CURRENT_USER${NC}"
echo -e "${YELLOW}Home-Verzeichnis: $USER_HOME${NC}\n"

# Stop and disable systemd user service
echo -e "${YELLOW}1. Stoppe systemd User-Service...${NC}"
if systemctl --user is-active --quiet smart-wifi-controller.service 2>/dev/null; then
    systemctl --user stop smart-wifi-controller.service
    echo -e "${GREEN}   ✓ Service gestoppt${NC}"
else
    echo -e "${BLUE}   - Service nicht aktiv (OK)${NC}"
fi

if systemctl --user is-enabled --quiet smart-wifi-controller.service 2>/dev/null; then
    systemctl --user disable smart-wifi-controller.service
    echo -e "${GREEN}   ✓ Service deaktiviert${NC}"
else
    echo -e "${BLUE}   - Service nicht aktiviert (OK)${NC}"
fi

# Remove systemd service file
echo -e "\n${YELLOW}2. Lösche Service-Datei...${NC}"
SERVICE_FILE="$USER_HOME/.config/systemd/user/smart-wifi-controller.service"
if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    echo -e "${GREEN}   ✓ Gelöscht: $SERVICE_FILE${NC}"
else
    echo -e "${BLUE}   - Datei nicht gefunden (OK)${NC}"
fi

# Remove daemon files
echo -e "\n${YELLOW}3. Lösche Daemon-Dateien...${NC}"
DAEMON_FILE="$USER_HOME/.local/bin/smart_wifi_daemon"
if [ -f "$DAEMON_FILE" ]; then
    rm -f "$DAEMON_FILE"
    echo -e "${GREEN}   ✓ Gelöscht: $DAEMON_FILE${NC}"
else
    echo -e "${BLUE}   - Datei nicht gefunden (OK)${NC}"
fi

# Remove configuration directory
echo -e "\n${YELLOW}4. Lösche Konfigurationsverzeichnis...${NC}"
CONFIG_DIR="$USER_HOME/.config/smart_wifi_controller"
if [ -d "$CONFIG_DIR" ]; then
    rm -rf "$CONFIG_DIR"
    echo -e "${GREEN}   ✓ Gelöscht: $CONFIG_DIR${NC}"
else
    echo -e "${BLUE}   - Verzeichnis nicht gefunden (OK)${NC}"
fi

# Remove log directory
echo -e "\n${YELLOW}5. Lösche Log-Verzeichnis...${NC}"
LOG_DIR="$USER_HOME/.local/share/smart_wifi_controller"
if [ -d "$LOG_DIR" ]; then
    rm -rf "$LOG_DIR"
    echo -e "${GREEN}   ✓ Gelöscht: $LOG_DIR${NC}"
else
    echo -e "${BLUE}   - Verzeichnis nicht gefunden (OK)${NC}"
fi

# Reload systemd user daemon
echo -e "\n${YELLOW}6. Aktualisiere systemd User-Daemon...${NC}"
systemctl --user daemon-reload
echo -e "${GREEN}   ✓ systemd reloaded${NC}"

# Show summary
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Deinstallation abgeschlossen!${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Entfernte Komponenten:${NC}"
echo "  • systemd User-Service"
echo "  • Daemon-Binärdatei"
echo "  • Konfigurationsdateien"
echo "  • Log-Dateien"

echo -e "\n${BLUE}Hinweis:${NC}"
echo "  • Die Sudoers-Ausnahmen bleiben bestehen (sicher)"
echo "  • Das Hauptskript bleibt in: /home/julbak/smart-wifi-controller/"
echo "  • Zum vollständigen Entfernen: sudo rm -rf /home/julbak/smart-wifi-controller"

echo ""
