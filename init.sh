#!/bin/bash

# Init Script für Network Manager
# Initialisiert das Projekt und richtet alles ein

set -euo pipefail

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Projekt-Informationen
PROJECT_NAME="Network Manager"
PROJECT_VERSION="1.0.0"
AUTHOR="dajuly20"
DATE=$(date '+%Y-%m-%d')

# Banner anzeigen
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Network Manager Init                      ║"
    echo "║              Automatische WiFi/LAN Verwaltung               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BLUE}Version:${NC} $PROJECT_VERSION"
    echo -e "${BLUE}Autor:${NC} $AUTHOR"
    echo -e "${BLUE}Datum:${NC} $DATE"
    echo ""
}

# Projekt-Verzeichnis-Struktur erstellen
create_project_structure() {
    echo -e "${YELLOW}Erstelle Projekt-Struktur...${NC}"
    
    # Basis-Verzeichnisse
    local dirs=(
        "docs"
        "config"
        "logs"
        "backup"
        "examples"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo -e "${GREEN}✓${NC} Verzeichnis erstellt: $dir"
        else
            echo -e "${YELLOW}⚠${NC} Verzeichnis existiert bereits: $dir"
        fi
    done
}

# Dokumentations-Dateien erstellen
create_documentation() {
    echo -e "${YELLOW}Erstelle Dokumentations-Dateien...${NC}"
    
    # .gitignore erstellen falls nicht vorhanden
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Logs
*.log
logs/

# Backup files
backup/
*.bak
*.backup

# Temporary files
*.tmp
/tmp/

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*~
.*.swp
.*.swo
*.orig

# Personal configuration
.personal_config
personal/
EOF
        echo -e "${GREEN}✓${NC} .gitignore erstellt"
    fi
    
    # LICENSE Datei erstellen
    if [ ! -f "LICENSE" ]; then
        cat > LICENSE << EOF
MIT License

Copyright (c) $(date +%Y) $AUTHOR

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
        echo -e "${GREEN}✓${NC} LICENSE erstellt"
    fi
    
    # CHANGELOG.md erstellen
    if [ ! -f "CHANGELOG.md" ]; then
        cat > CHANGELOG.md << EOF
# Changelog

Alle bedeutsamen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - $DATE

### Hinzugefügt
- Initiale Implementierung des Network Manager Scripts
- GUI-Interface mit Zenity/KDialog Support
- Automatische WiFi/Ethernet Verwaltung
- "Immer so"-Checkbox für Automatisierung
- Daemon-Modus für Hintergrundausführung
- Konfigurationsverwaltung
- Autostart-Integration
- Installations-Script
- Test-Suite
- Umfassende Dokumentation

### Funktionen
- Intelligente Netzwerkerkennung
- Automatisches WiFi deaktivieren bei Ethernet-Verbindung
- Automatisches WiFi aktivieren bei Ethernet-Trennung
- GUI-Prompts für Benutzerinteraktion
- Persistente Konfigurationsspeicherung
- Desktop-Integration
- Multi-Distro-Support

### Technische Details
- NetworkManager Integration über nmcli
- Cross-Desktop GUI Support (Zenity/KDialog)
- Robuste Fehlerbehandlung
- Umfassives Logging
- Modulare Architektur
EOF
        echo -e "${GREEN}✓${NC} CHANGELOG.md erstellt"
    fi
}

# Beispiel-Konfigurationsdateien erstellen
create_example_configs() {
    echo -e "${YELLOW}Erstelle Beispiel-Konfigurationen...${NC}"
    
    # Beispiel-Konfiguration
    cat > config/example_config.conf << EOF
# Network Manager - Beispiel-Konfiguration
# Diese Datei zeigt alle verfügbaren Optionen

# Automatische Verwaltung aktivieren
AUTO_MANAGE=true

# Intervall für Daemon-Checks (Sekunden)
CHECK_INTERVAL=5

# Logging-Level (debug, info, warning, error)
LOG_LEVEL=info

# Notification-Einstellungen
SHOW_NOTIFICATIONS=true
NOTIFICATION_TIMEOUT=5000

# Netzwerk-Interface-Filter
# Leer lassen für automatische Erkennung
ETHERNET_INTERFACES=""
WIFI_INTERFACES=""

# Erweiterte Optionen
FORCE_WIFI_OFF_ON_ETHERNET=true
AUTO_RECONNECT_WIFI=true
DELAY_BEFORE_WIFI_OFF=2
DELAY_BEFORE_WIFI_ON=1
EOF
    echo -e "${GREEN}✓${NC} Beispiel-Konfiguration erstellt: config/example_config.conf"
    
    # Systemd-Service Beispiel
    cat > examples/smart-wifi-controller.service << EOF
[Unit]
Description=Smart WiFi Controller Service
After=network.target

[Service]
Type=simple
User=\$USER
ExecStart=/usr/local/bin/smart-wifi-controller --daemon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}✓${NC} Systemd-Service Beispiel erstellt: examples/smart-wifi-controller.service"
}

# Alle Scripts ausführbar machen
make_scripts_executable() {
    echo -e "${YELLOW}Setze Ausführungsrechte...${NC}"
    
    local scripts=(
        "network_manager.sh"
        "install.sh"
        "test.sh"
        "init.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            echo -e "${GREEN}✓${NC} $script ist ausführbar"
        else
            echo -e "${RED}✗${NC} $script nicht gefunden"
        fi
    done
}

# System-Abhängigkeiten prüfen
check_dependencies() {
    echo -e "${YELLOW}Prüfe System-Abhängigkeiten...${NC}"
    
    local deps=(
        "bash:Bash Shell"
        "nmcli:NetworkManager"
        "python3:Python 3"
    )

    local gui_deps=(
        "zenity:Zenity (GUI)"
        "kdialog:KDialog (GUI)"
    )

    local python_deps=(
        "gi:PyGObject (für System Tray)"
    )
    
    local missing=()
    local gui_available=false
    local need_install=false
    
    # Kern-Abhängigkeiten prüfen
    for dep in "${deps[@]}"; do
        local cmd="${dep%%:*}"
        local name="${dep##*:}"
        
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $name verfügbar"
        else
            echo -e "${RED}✗${NC} $name fehlt"
            missing+=("$cmd")
            need_install=true
        fi
    done
    
    # GUI-Abhängigkeiten prüfen
    for dep in "${gui_deps[@]}"; do
        local cmd="${dep%%:*}"
        local name="${dep##*:}"
        
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $name verfügbar"
            gui_available=true
        fi
    done
    
    if [ "$gui_available" = false ]; then
        echo -e "${YELLOW}⚠${NC} Kein GUI-Toolkit gefunden (zenity oder kdialog empfohlen)"
        missing+=("zenity")
        need_install=true
    fi
    
    # Automatische Installation anbieten
    if [ "$need_install" = true ]; then
        echo ""
        echo -e "${RED}Fehlende Abhängigkeiten:${NC}"
        for dep in "${missing[@]}"; do
            echo -e "  ${RED}•${NC} $dep"
        done
        echo ""
        
        # Betriebssystem erkennen
        local os_info=""
        local install_cmd=""
        
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian|pop|linuxmint)
                    os_info="Ubuntu/Debian-basiert"
                    install_cmd="sudo apt update && sudo apt install -y network-manager zenity python3 libappindicator3-1 gir1.2-appindicator3-0.1 python3-gi"
                    ;;
                fedora|rhel|centos|rocky|almalinux)
                    os_info="Fedora/RHEL-basiert"
                    install_cmd="sudo dnf install -y NetworkManager zenity python3 libappindicator-gtk3 python3-gobject"
                    ;;
                opensuse*|sles)
                    os_info="openSUSE"
                    install_cmd="sudo zypper install -y NetworkManager zenity python3 libappindicator1 python3-gobject"
                    ;;
                arch|manjaro|endeavouros)
                    os_info="Arch-basiert"
                    install_cmd="sudo pacman -S --needed networkmanager zenity python3 libappindicator-gtk3 python-gobject"
                    ;;
                *)
                    os_info="Unbekannt"
                    ;;
            esac
        fi
        
        echo -e "${BLUE}Erkanntes System:${NC} $os_info"
        echo ""
        
        if [ -n "$install_cmd" ]; then
            echo -e "${YELLOW}Soll ich die fehlenden Pakete automatisch installieren?${NC}"
            echo -e "${CYAN}Kommando:${NC} $install_cmd"
            echo ""
            read -p "Automatisch installieren? (y/N): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}Installiere Abhängigkeiten...${NC}"
                
                if eval "$install_cmd"; then
                    echo -e "${GREEN}✓${NC} Installation erfolgreich!"
                     echo ""
                    
                    # Erneute Prüfung
                    echo -e "${BLUE}Führe erneute Überprüfung durch...${NC}"
                    check_dependencies_simple
                else
                    echo -e "${RED}✗${NC} Installation fehlgeschlagen!"
                    echo ""
                    echo "Bitte installieren Sie die Pakete manuell:"
                    echo "$install_cmd"
                    return 1
                fi
            else
                echo -e "${YELLOW}⚠${NC} Installation übersprungen."
                echo ""
                echo "Manuelle Installation erforderlich:"
                echo "$install_cmd"
                return 1
            fi
        else
            echo "Bitte installieren Sie die fehlenden Pakete manuell für Ihr System."
            return 1
        fi
    else
        echo -e "${GREEN}✓${NC} Alle Abhängigkeiten erfüllt"
    fi
    
    return 0
}

# Vereinfachte Abhängigkeitsprüfung (ohne Installation)
check_dependencies_simple() {
    local all_ok=true
    
    if ! command -v nmcli &> /dev/null; then
        echo -e "${RED}✗${NC} NetworkManager noch nicht verfügbar"
        all_ok=false
    else
        echo -e "${GREEN}✓${NC} NetworkManager verfügbar"
    fi
    
    if ! command -v zenity &> /dev/null && ! command -v kdialog &> /dev/null; then
        echo -e "${RED}✗${NC} GUI-Toolkit noch nicht verfügbar"
        all_ok=false
    else
        echo -e "${GREEN}✓${NC} GUI-Toolkit verfügbar"
    fi
    
    if [ "$all_ok" = true ]; then
        echo -e "${GREEN}✓${NC} Alle Abhängigkeiten sind jetzt verfügbar!"
    else
        echo -e "${YELLOW}⚠${NC} Einige Abhängigkeiten fehlen noch."
    fi
}

# Git-Repository initialisieren (falls gewünscht)
setup_git() {
    if [ -d ".git" ]; then
        echo -e "${YELLOW}⚠${NC} Git-Repository bereits initialisiert"
        return
    fi
    
    read -p "Git-Repository initialisieren? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Initialisiere Git-Repository...${NC}"
        
        git init
        git add .
        git commit -m "Initial commit: Network Manager v$PROJECT_VERSION"
        
        echo -e "${GREEN}✓${NC} Git-Repository initialisiert"
        echo ""
        echo "Nächste Schritte für Remote-Repository:"
        echo "  git remote add origin <repository-url>"
        echo "  git branch -M main"
        echo "  git push -u origin main"
    fi
}

# Hauptfunktion
main() {
    show_banner
    
    echo -e "${BLUE}Starte Projekt-Initialisierung...${NC}"
    echo ""
    
    create_project_structure
    echo ""
    
    create_documentation
    echo ""
    
    create_example_configs
    echo ""
    
    make_scripts_executable
    echo ""
    
    if check_dependencies; then
        echo ""
        echo -e "${GREEN}System bereit für Network Manager!${NC}"
    else
        echo ""
        echo -e "${YELLOW}Bitte installiere fehlende Abhängigkeiten vor der ersten Nutzung.${NC}"
    fi
    
    echo ""
    setup_git
    
    echo ""
    echo -e "${CYAN}Initialisierung abgeschlossen!${NC}"
    echo ""
    echo -e "${BLUE}Nächste Schritte:${NC}"
    echo "1. Abhängigkeiten installieren (falls erforderlich)"
    echo "2. Test ausführen: ./test.sh"
    echo "3. Installation: sudo ./install.sh"
    echo "4. Erste Nutzung: ./network_manager.sh"
    echo ""
    echo -e "${BLUE}Dokumentation:${NC}"
    echo "• README.md - Vollständige Anleitung"
    echo "• PSEUDOCODE_README.md - Technische Dokumentation"
    echo "• docs/ - Zusätzliche Dokumentation"
    echo ""
    echo -e "${GREEN}Viel Erfolg mit dem Network Manager!${NC}"
}

# Script ausführen
main "$@"