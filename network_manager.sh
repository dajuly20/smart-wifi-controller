#!/bin/bash

# Network Manager Script with GUI (Single-Run Mode)
# Manages WiFi based on Ethernet connection status - single execution only
# Author: Network Management Script
# Date: $(date)

# Configuration file for automation settings (simplified - not used in single-run mode)
CONFIG_FILE="$HOME/.config/network_manager_config"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/tmp/network_manager.log"

# Function to log messages
log_message() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    echo -e "${BLUE}[INFO]${NC} $message"
}

# Function to check if required tools are installed
check_dependencies() {
    local missing_tools=()
    
    # Check for NetworkManager
    if ! command -v nmcli &> /dev/null; then
        missing_tools+=("NetworkManager (nmcli)")
    fi
    
    # Check for GUI tools
    if ! command -v zenity &> /dev/null && ! command -v kdialog &> /dev/null; then
        missing_tools+=("zenity oder kdialog")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}Fehler: Folgende Tools fehlen:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Installation unter Ubuntu/Debian:"
        echo "sudo apt update && sudo apt install network-manager zenity"
        echo ""
        echo "Installation unter Fedora/RHEL:"
        echo "sudo dnf install NetworkManager zenity"
        exit 1
    fi
}

# Function to detect GUI toolkit
get_gui_command() {
    if command -v zenity &> /dev/null; then
        echo "zenity"
    elif command -v kdialog &> /dev/null; then
        echo "kdialog"
    else
        return 1
    fi
}

# Function to show GUI message
show_message() {
    local title="$1"
    local message="$2"
    local type="${3:-info}" # info, warning, error
    
    local gui_cmd=$(get_gui_command)
    
    case "$gui_cmd" in
        "zenity")
            case "$type" in
                "error")
                    zenity --error --title="$title" --text="$message" --width=400
                    ;;
                "warning")
                    zenity --warning --title="$title" --text="$message" --width=400
                    ;;
                *)
                    zenity --info --title="$title" --text="$message" --width=400
                    ;;
            esac
            ;;
        "kdialog")
            case "$type" in
                "error")
                    kdialog --error "$message" --title "$title"
                    ;;
                "warning")
                    kdialog --sorry "$message" --title "$title"
                    ;;
                *)
                    kdialog --msgbox "$message" --title "$title"
                    ;;
            esac
            ;;
    esac
}

# Function to get network interface status
get_ethernet_status() {
    # Get all ethernet connections that are up
    local eth_connections=$(nmcli -t -f NAME,TYPE,STATE connection show --active | grep ethernet | grep activated)
    if [ -n "$eth_connections" ]; then
        echo "connected"
    else
        echo "disconnected"
    fi
}

# Function to get WiFi status
get_wifi_status() {
    local wifi_state=$(nmcli radio wifi)
    echo "$wifi_state"
}

# Function to enable/disable WiFi
toggle_wifi() {
    local action="$1" # on or off
    
    if [ "$action" = "on" ]; then
        log_message "Aktiviere WiFi..."
        nmcli radio wifi on
        if [ $? -eq 0 ]; then
            log_message "WiFi erfolgreich aktiviert"
            return 0
        else
            log_message "Fehler beim Aktivieren von WiFi"
            return 1
        fi
    elif [ "$action" = "off" ]; then
        log_message "Deaktiviere WiFi..."
        nmcli radio wifi off
        if [ $? -eq 0 ]; then
            log_message "WiFi erfolgreich deaktiviert"
            return 0
        else
            log_message "Fehler beim Deaktivieren von WiFi"
            return 1
        fi
    fi
}

# Function to check and manage network connections
manage_connections() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    local action_taken=""
    
    log_message "Ethernet Status: $eth_status"
    log_message "WiFi Status: $wifi_status"
    
    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "enabled" ]; then
        # Ethernet connected and WiFi enabled -> disable WiFi
        log_message "Ethernet verbunden und WiFi aktiv - deaktiviere WiFi"
        if toggle_wifi "off"; then
            action_taken="WiFi wurde deaktiviert (Ethernet-Verbindung erkannt)"
        else
            action_taken="Fehler beim Deaktivieren von WiFi"
        fi
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "disabled" ]; then
        # Ethernet disconnected and WiFi disabled -> enable WiFi
        log_message "Ethernet getrennt und WiFi inaktiv - aktiviere WiFi"
        if toggle_wifi "on"; then
            action_taken="WiFi wurde aktiviert (keine Ethernet-Verbindung)"
        else
            action_taken="Fehler beim Aktivieren von WiFi"
        fi
    else
        log_message "Keine Aktion erforderlich"
        action_taken="Keine Änderung erforderlich (Ethernet: $eth_status, WiFi: $wifi_status)"
    fi
    
    echo "$action_taken"
}

# Function to show current status
show_status() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    
    local status_text="Aktueller Netzwerk-Status:

Ethernet: $eth_status
WiFi: $wifi_status"
    
    show_message "Netzwerk-Status" "$status_text"
}

# Function to show interactive GUI (simplified - no automation)
show_gui() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    
    local action_text=""
    local question=""
    
    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "enabled" ]; then
        question="Ethernet-Verbindung erkannt und WiFi ist aktiv.

Möchten Sie WiFi deaktivieren?"
        action_text="WiFi deaktivieren"
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "disabled" ]; then
        question="Keine Ethernet-Verbindung und WiFi ist deaktiviert.

Möchten Sie WiFi aktivieren?"
        action_text="WiFi aktivieren"
    else
        show_message "Netzwerk-Manager" "Keine Aktion erforderlich.

Ethernet: $eth_status
WiFi: $wifi_status" "info"
        return 0
    fi
    
    # Show simple GUI question (no automation checkbox)
    local gui_cmd=$(get_gui_command)
    local user_choice=""
    
    if [ "$gui_cmd" = "zenity" ]; then
        # Use simple zenity question dialog
        if zenity --question \
            --title="Netzwerk-Manager" \
            --text="$question" \
            --width=400 --height=150; then
            user_choice="Ja"
        else
            user_choice="Nein"
        fi
    else
        # KDialog fallback
        if kdialog --yesno "$question" --title "Netzwerk-Manager"; then
            user_choice="Ja"
        else
            user_choice="Nein"
        fi
    fi
    
    # Process user choice
    if [ "$user_choice" = "Ja" ]; then
        local result=$(manage_connections)
        show_message "Netzwerk-Manager" "Aktion ausgeführt: $result" "info"
    else
        show_message "Netzwerk-Manager" "Aktion abgebrochen." "info"
    fi
}

# Main script logic
main() {
    case "${1:-}" in
        --status)
            show_status
            ;;
        --manual)
            local result=$(manage_connections)
            echo "$result"
            ;;
        --help|-h)
            cat << EOF
Network Manager Script - Einmalige WiFi/Ethernet Verwaltung

Verwendung:
  $0                 Interaktive GUI (Standard)
  $0 --status        Aktuellen Status anzeigen
  $0 --manual        Einmalige manuelle Ausführung (ohne GUI)
  $0 --help          Diese Hilfe anzeigen

Das Script überprüft einmalig die Netzwerkverbindungen und bietet
an, WiFi zu deaktivieren (bei Ethernet) oder zu aktivieren (ohne Ethernet).
EOF
            ;;
        *)
            # Default: Show interactive GUI
            check_dependencies
            show_gui
            ;;
    esac
}

# Run main function with all arguments
main "$@"