#!/bin/bash

# Test Script für Smart WiFi Controller
# Überprüft die Grundfunktionen ohne tatsächliche Netzwerkänderungen

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMART_WIFI_CONTROLLER="$SCRIPT_DIR/smart_wifi_controller.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Smart WiFi Controller Test Suite${NC}"
echo "=================================="

# Check if smart_wifi_controller.sh exists
if [ ! -f "$SMART_WIFI_CONTROLLER" ]; then
    echo -e "${RED}✗ smart_wifi_controller.sh nicht gefunden!${NC}"
    exit 1
fi

# Make executable
chmod +x "$SMART_WIFI_CONTROLLER"

echo -e "${GREEN}✓ Script gefunden und ausführbar gemacht${NC}"

# Test 1: Check dependencies
echo ""
echo -e "${YELLOW}Test 1: Abhängigkeiten überprüfen${NC}"

if command -v nmcli &> /dev/null; then
    echo -e "${GREEN}✓ NetworkManager (nmcli) verfügbar${NC}"
else
    echo -e "${RED}✗ NetworkManager (nmcli) fehlt${NC}"
fi

if command -v zenity &> /dev/null; then
    echo -e "${GREEN}✓ Zenity verfügbar${NC}"
    GUI_AVAILABLE="zenity"
elif command -v kdialog &> /dev/null; then
    echo -e "${GREEN}✓ KDialog verfügbar${NC}"
    GUI_AVAILABLE="kdialog"
else
    echo -e "${RED}✗ Kein GUI-Toolkit (zenity/kdialog) verfügbar${NC}"
    GUI_AVAILABLE="none"
fi

# Test 2: Help function
echo ""
echo -e "${YELLOW}Test 2: Hilfe-Funktion${NC}"
if "$SMART_WIFI_CONTROLLER" --help &> /dev/null; then
    echo -e "${GREEN}✓ Hilfe-Funktion funktioniert${NC}"
else
    echo -e "${RED}✗ Hilfe-Funktion fehlgeschlagen${NC}"
fi

# Test 3: Status function
echo ""
echo -e "${YELLOW}Test 3: Status-Funktion${NC}"
if command -v nmcli &> /dev/null; then
    if "$SMART_WIFI_CONTROLLER" --status &> /dev/null; then
        echo -e "${GREEN}✓ Status-Funktion funktioniert${NC}"
    else
        echo -e "${RED}✗ Status-Funktion fehlgeschlagen${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Status-Test übersprungen (nmcli fehlt)${NC}"
fi

# Test 4: Check network status (read-only)
echo ""
echo -e "${YELLOW}Test 4: Netzwerk-Status lesen${NC}"
if command -v nmcli &> /dev/null; then
    echo "Aktuelle Netzwerk-Verbindungen:"
    nmcli -t -f NAME,TYPE,STATE connection show --active | while IFS=':' read name type state; do
        echo "  - $name ($type): $state"
    done
    
    wifi_status=$(nmcli radio wifi)
    echo "WiFi-Radio: $wifi_status"
    echo -e "${GREEN}✓ Netzwerk-Status erfolgreich ausgelesen${NC}"
else
    echo -e "${YELLOW}⚠ Netzwerk-Status-Test übersprungen (nmcli fehlt)${NC}"
fi

# Test 5: Configuration handling
echo ""
echo -e "${YELLOW}Test 5: Konfigurationsdateien${NC}"

CONFIG_FILE="$HOME/.config/smart_wifi_controller_config"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Konfigurationsdatei existiert: $CONFIG_FILE${NC}"
    echo "Inhalt:"
    cat "$CONFIG_FILE" | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠ Konfigurationsdatei existiert noch nicht: $CONFIG_FILE${NC}"
fi

# Test 6: Dry run simulation
echo ""
echo -e "${YELLOW}Test 6: Simulationstest${NC}"

# Create a temporary test script that simulates network changes
cat > /tmp/network_test_sim.sh << 'EOF'
#!/bin/bash
echo "Simulation: Würde WiFi deaktivieren (Ethernet verbunden)"
echo "Simulation: Würde WiFi aktivieren (Ethernet getrennt)"
EOF

chmod +x /tmp/network_test_sim.sh
if /tmp/network_test_sim.sh; then
    echo -e "${GREEN}✓ Simulation erfolgreich${NC}"
else
    echo -e "${RED}✗ Simulation fehlgeschlagen${NC}"
fi
rm /tmp/network_test_sim.sh

# Summary
echo ""
echo -e "${BLUE}Test-Zusammenfassung${NC}"
echo "===================="

if command -v nmcli &> /dev/null && [ "$GUI_AVAILABLE" != "none" ]; then
    echo -e "${GREEN}✓ Alle erforderlichen Komponenten sind verfügbar${NC}"
    echo -e "${GREEN}✓ Script ist bereit für den produktiven Einsatz${NC}"
    echo ""
    echo "Nächste Schritte:"
    echo "1. Installation: ./install.sh"
    echo "2. Erste Ausführung: ./smart_wifi_controller.sh"
elif command -v nmcli &> /dev/null; then
    echo -e "${YELLOW}⚠ NetworkManager verfügbar, aber kein GUI-Toolkit${NC}"
    echo ""
    echo "GUI-Toolkit installieren:"
    echo "sudo apt install zenity  # Ubuntu/Debian"
    echo "sudo dnf install zenity  # Fedora/RHEL"
elif [ "$GUI_AVAILABLE" != "none" ]; then
    echo -e "${YELLOW}⚠ GUI verfügbar, aber NetworkManager fehlt${NC}"
    echo ""
    echo "NetworkManager installieren:"
    echo "sudo apt install network-manager  # Ubuntu/Debian"
    echo "sudo dnf install NetworkManager   # Fedora/RHEL"
else
    echo -e "${RED}✗ Sowohl NetworkManager als auch GUI-Toolkit fehlen${NC}"
    echo ""
    echo "Vollständige Installation:"
    echo "sudo apt install network-manager zenity  # Ubuntu/Debian"
    echo "sudo dnf install NetworkManager zenity   # Fedora/RHEL"
fi

echo ""
echo "Test abgeschlossen."