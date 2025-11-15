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
LOG_FILE="$HOME/.local/share/network_manager/network_manager.log"

# Function to ensure log directory exists
ensure_log_directory() {
    local log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi
}

# Function to log messages with different levels
log_message() {
    local level="${1:-INFO}"
    local message="$2"
    
    # If only one parameter is provided, treat it as INFO level message
    if [ -z "$message" ]; then
        message="$level"
        level="INFO"
    fi
    
    ensure_log_directory
    
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file
    echo "$log_entry" >> "$LOG_FILE"
    
    # Also display on console with color coding
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        *)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

# Function to check if required tools are installed
check_dependencies() {
    local missing_tools=()
    
    log_message "INFO" "Überprüfe Systemabhängigkeiten..."
    
    # Check for NetworkManager
    if ! command -v nmcli &> /dev/null; then
        missing_tools+=("NetworkManager (nmcli)")
        log_message "ERROR" "NetworkManager (nmcli) nicht gefunden"
    else
        log_message "INFO" "NetworkManager verfügbar"
    fi
    
    # Check for GUI tools
    if ! command -v zenity &> /dev/null && ! command -v kdialog &> /dev/null; then
        missing_tools+=("zenity oder kdialog")
        log_message "ERROR" "Kein GUI-Toolkit gefunden (zenity/kdialog)"
    else
        if command -v zenity &> /dev/null; then
            log_message "INFO" "Zenity GUI verfügbar"
        fi
        if command -v kdialog &> /dev/null; then
            log_message "INFO" "KDialog GUI verfügbar"
        fi
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_message "ERROR" "Abhängigkeiten fehlen: ${missing_tools[*]}"
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
    
    log_message "SUCCESS" "Alle Abhängigkeiten erfüllt"
}

# Function to get the last N log entries
get_recent_logs() {
    local num_entries="${1:-15}"
    
    if [ -f "$LOG_FILE" ]; then
        tail -n "$num_entries" "$LOG_FILE"
    else
        echo "Keine Log-Einträge vorhanden."
    fi
}

# Function to show log entries in GUI
show_log_gui() {
    local recent_logs=$(get_recent_logs 15)
    local gui_cmd=$(get_gui_command)
    
    if [ "$gui_cmd" = "zenity" ]; then
        echo "$recent_logs" | zenity --text-info \
            --title="Network Manager - Log-Einträge (letzte 15)" \
            --width=800 --height=500 \
            --font="Monospace 10"
    else
        # KDialog fallback
        kdialog --textbox <(echo "$recent_logs") 800 500 \
            --title "Network Manager - Log-Einträge (letzte 15)"
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
        log_message "INFO" "Versuche WiFi zu aktivieren..."
        if nmcli radio wifi on 2>/dev/null; then
            log_message "SUCCESS" "WiFi erfolgreich aktiviert"
            return 0
        else
            log_message "ERROR" "Fehler beim Aktivieren von WiFi"
            return 1
        fi
    elif [ "$action" = "off" ]; then
        log_message "INFO" "Versuche WiFi zu deaktivieren..."
        if nmcli radio wifi off 2>/dev/null; then
            log_message "SUCCESS" "WiFi erfolgreich deaktiviert"
            return 0
        else
            log_message "ERROR" "Fehler beim Deaktivieren von WiFi"
            return 1
        fi
    else
        log_message "ERROR" "Ungültiger Parameter für toggle_wifi: $action"
        return 1
    fi
}

# Function to check and manage network connections
manage_connections() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    local action_taken=""
    
    log_message "INFO" "=== Netzwerk-Check gestartet ==="
    log_message "INFO" "Ethernet Status: $eth_status"
    log_message "INFO" "WiFi Status: $wifi_status"
    
    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "enabled" ]; then
        # Ethernet connected and WiFi enabled -> disable WiFi
        log_message "INFO" "Ethernet verbunden und WiFi aktiv - deaktiviere WiFi"
        if toggle_wifi "off"; then
            action_taken="WiFi wurde deaktiviert (Ethernet-Verbindung erkannt)"
            log_message "SUCCESS" "$action_taken"
        else
            action_taken="Fehler beim Deaktivieren von WiFi"
            log_message "ERROR" "$action_taken"
        fi
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "disabled" ]; then
        # Ethernet disconnected and WiFi disabled -> enable WiFi
        log_message "INFO" "Ethernet getrennt und WiFi inaktiv - aktiviere WiFi"
        if toggle_wifi "on"; then
            action_taken="WiFi wurde aktiviert (keine Ethernet-Verbindung)"
            log_message "SUCCESS" "$action_taken"
        else
            action_taken="Fehler beim Aktivieren von WiFi"
            log_message "ERROR" "$action_taken"
        fi
    else
        log_message "INFO" "Keine Aktion erforderlich"
        action_taken="Keine Änderung erforderlich (Ethernet: $eth_status, WiFi: $wifi_status)"
    fi
    
    log_message "INFO" "=== Netzwerk-Check beendet ==="
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
    
    log_message "INFO" "GUI gestartet - Ethernet: $eth_status, WiFi: $wifi_status"
    
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
        # Show status with log option
        local status_text="Keine Aktion erforderlich.

Ethernet: $eth_status
WiFi: $wifi_status

Möchten Sie die letzten Log-Einträge anzeigen?"
        
        local gui_cmd=$(get_gui_command)
        if [ "$gui_cmd" = "zenity" ]; then
            if zenity --question \
                --title="Netzwerk-Manager" \
                --text="$status_text" \
                --ok-label="Log anzeigen" \
                --cancel-label="Schließen" \
                --width=400 --height=200; then
                show_log_gui
            fi
        else
            if kdialog --yesno "$status_text" --title "Netzwerk-Manager" \
                --yes-label "Log anzeigen" --no-label "Schließen"; then
                show_log_gui
            fi
        fi
        return 0
    fi
    
    # Show GUI question with additional log option
    local gui_cmd=$(get_gui_command)
    local user_choice=""
    
    if [ "$gui_cmd" = "zenity" ]; then
        # Create a custom dialog with multiple buttons
        zenity --question \
            --title="Netzwerk-Manager" \
            --text="$question" \
            --width=450 --height=200 \
            --extra-button="Log anzeigen" \
            --ok-label="Ja" \
            --cancel-label="Nein"
        
        local result=$?
        case $result in
            0) user_choice="Ja" ;;
            1) user_choice="Nein" ;;
            *) 
                show_log_gui
                # Ask again after showing log
                if zenity --question \
                    --title="Netzwerk-Manager" \
                    --text="$question" \
                    --width=400 --height=150; then
                    user_choice="Ja"
                else
                    user_choice="Nein"
                fi
                ;;
        esac
    else
        # KDialog fallback - simpler approach
        if kdialog --yesno "$question" --title "Netzwerk-Manager"; then
            user_choice="Ja"
        else
            user_choice="Nein"
        fi
    fi
    
    # Process user choice
    if [ "$user_choice" = "Ja" ]; then
        local result=$(manage_connections)
        
        # Show result with option to view logs
        if [ "$gui_cmd" = "zenity" ]; then
            zenity --info \
                --title="Netzwerk-Manager" \
                --text="Aktion ausgeführt: $result

Möchten Sie die Log-Einträge anzeigen?" \
                --width=450 \
                --extra-button="Log anzeigen"
            
            if [ $? -ne 0 ]; then
                show_log_gui
            fi
        else
            kdialog --msgbox "Aktion ausgeführt: $result" --title "Netzwerk-Manager"
        fi
        
        log_message "INFO" "Benutzeraktion abgeschlossen"
    else
        log_message "INFO" "Benutzer hat Aktion abgebrochen"
        show_message "Netzwerk-Manager" "Aktion abgebrochen." "info"
    fi
}

# Main script logic
main() {
    # Log script startup
    log_message "INFO" "======================================"
    log_message "INFO" "Network Manager Script gestartet"
    log_message "INFO" "Parameter: ${*:-'(keine)'}"
    log_message "INFO" "======================================"
    
    case "${1:-}" in
        --status)
            show_status
            ;;
        --log|--logs)
            if command -v zenity &> /dev/null || command -v kdialog &> /dev/null; then
                show_log_gui
            else
                echo "=== Network Manager Log (letzte 15 Einträge) ==="
                get_recent_logs 15
            fi
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
  $0 --log           Log-Einträge anzeigen (letzte 15)
  $0 --manual        Einmalige manuelle Ausführung (ohne GUI)
  $0 --help          Diese Hilfe anzeigen

Das Script überprüft einmalig die Netzwerkverbindungen und bietet
an, WiFi zu deaktivieren (bei Ethernet) oder zu aktivieren (ohne Ethernet).

Log-Datei: $LOG_FILE
EOF
            ;;
        *)
            # Default: Show interactive GUI
            check_dependencies
            log_message "INFO" "Network Manager gestartet (GUI-Modus)"
            show_gui
            ;;
    esac
}

# Run main function with all arguments
main "$@"