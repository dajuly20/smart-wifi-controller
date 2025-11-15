#!/bin/bash

# Smart WiFi Controller Script with GUI (Single-Run Mode)
# Intelligently manages WiFi based on Ethernet connection status - single execution only
# Author: Smart WiFi Controller Script
# Date: $(date)

# Configuration file for settings (simplified - not used in single-run mode)
CONFIG_FILE="$HOME/.config/smart_wifi_controller_config"

# Temporary decision file (until reboot)
TEMP_DECISION_FILE="/tmp/smart_wifi_controller_decision"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="$HOME/.local/share/smart_wifi_controller/smart_wifi_controller.log"

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

# Function to save user decision until reboot
save_decision() {
    local decision="$1"
    echo "$decision" > "$TEMP_DECISION_FILE"
    log_message "INFO" "Benutzer-Entscheidung gespeichert: $decision"
}

# Function to check saved decision
check_saved_decision() {
    if [ -f "$TEMP_DECISION_FILE" ]; then
        cat "$TEMP_DECISION_FILE"
        return 0
    else
        return 1
    fi
}

# Function to clear saved decision
clear_saved_decision() {
    if [ -f "$TEMP_DECISION_FILE" ]; then
        rm -f "$TEMP_DECISION_FILE"
        log_message "INFO" "Gespeicherte Entscheidung gelöscht"
    fi
}

# Function to get network interface details
get_interface_details() {
    local interface="$1"
    local details=""
    
    if [ -z "$interface" ] || [ "$interface" = "--" ]; then
        echo "Nicht verfügbar"
        return
    fi
    
    # Get IP address
    local ip_addr=$(ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -n1)
    if [ -z "$ip_addr" ]; then
        ip_addr="Keine IP"
    fi
    
    # Get link speed and additional details
    local speed=""
    local connection_type=""
    local additional_info=""
    
    if [[ "$interface" =~ ^(eth|enp|eno|ens) ]]; then
        # Ethernet interface
        connection_type="Ethernet"
        
        # Try multiple methods to get speed
        speed=$(ethtool "$interface" 2>/dev/null | grep "Speed:" | awk '{print $2}')
        if [ -z "$speed" ] || [ "$speed" = "Unknown!" ]; then
            speed=$(cat "/sys/class/net/$interface/speed" 2>/dev/null)
            if [ -n "$speed" ] && [ "$speed" != "0" ] && [ "$speed" != "-1" ]; then
                speed="${speed}Mbps"
            else
                speed="Unbekannt"
            fi
        fi
        
        # Get duplex mode
        local duplex=$(ethtool "$interface" 2>/dev/null | grep "Duplex:" | awk '{print $2}')
        if [ -n "$duplex" ]; then
            additional_info="$duplex"
        fi
        
        # Check carrier status
        local carrier=$(cat "/sys/class/net/$interface/carrier" 2>/dev/null)
        if [ "$carrier" = "1" ]; then
            additional_info="$additional_info, Link aktiv"
        else
            additional_info="$additional_info, Kein Link"
        fi
        
    elif [[ "$interface" =~ ^(wlan|wlp|wlo) ]]; then
        # WiFi interface
        connection_type="WiFi"
        
        # Get WiFi details using iw
        local wifi_info=$(iw dev "$interface" link 2>/dev/null)
        if [ -n "$wifi_info" ]; then
            # Signal strength
            local signal=$(echo "$wifi_info" | grep "signal:" | awk '{print $2 " " $3}')
            
            # TX bitrate (upload speed)
            local tx_rate=$(echo "$wifi_info" | grep "tx bitrate:" | awk '{print $3 " " $4}')
            
            # RX bitrate (download speed) if available
            local rx_rate=$(echo "$wifi_info" | grep "rx bitrate:" | awk '{print $3 " " $4}')
            
            # WiFi frequency
            local freq=$(echo "$wifi_info" | grep "freq:" | awk '{print $2}')
            
            # SSID
            local ssid=$(echo "$wifi_info" | grep "SSID:" | awk '{print $2}')
            
            # Build speed info
            if [ -n "$tx_rate" ]; then
                speed="↑$tx_rate"
                if [ -n "$rx_rate" ]; then
                    speed="$speed / ↓$rx_rate"
                fi
            elif [ -n "$signal" ]; then
                speed="Verbunden"
            else
                speed="WiFi aktiv"
            fi
            
            # Build additional info
            if [ -n "$signal" ]; then
                additional_info="Signal: $signal"
            fi
            if [ -n "$freq" ]; then
                if [ -n "$additional_info" ]; then
                    additional_info="$additional_info, ${freq}MHz"
                else
                    additional_info="${freq}MHz"
                fi
            fi
            if [ -n "$ssid" ] && [ "$ssid" != "" ]; then
                if [ -n "$additional_info" ]; then
                    additional_info="$additional_info, SSID: $ssid"
                else
                    additional_info="SSID: $ssid"
                fi
            fi
        else
            # Fallback: check if interface is up
            local state=$(cat "/sys/class/net/$interface/operstate" 2>/dev/null)
            if [ "$state" = "up" ]; then
                speed="WiFi aktiv"
                additional_info="Status: up"
            else
                speed="WiFi inaktiv"
                additional_info="Status: $state"
            fi
        fi
        
    else
        # Unknown interface type
        connection_type="Unbekannt"
        local state=$(cat "/sys/class/net/$interface/operstate" 2>/dev/null)
        speed="Status: ${state:-unbekannt}"
    fi
    
    # Format output
    local result="IP: $ip_addr"
    if [ -n "$speed" ] && [ "$speed" != "Unbekannt" ]; then
        result="$result | Speed: $speed"
    fi
    if [ -n "$additional_info" ]; then
        result="$result | $additional_info"
    fi
    
    echo "$result"
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
            --title="Smart WiFi Controller - Log-Einträge (letzte 15)" \
            --width=800 --height=500 \
            --font="Monospace 10"
    else
        # KDialog fallback
        kdialog --textbox <(echo "$recent_logs") 800 500 \
            --title "Smart WiFi Controller - Log-Einträge (letzte 15)"
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
    
    # Get network interface details
    local eth_interface=$(nmcli -t -f DEVICE,TYPE device status | grep ":ethernet" | head -n1 | cut -d: -f1)
    local wifi_interface=$(nmcli -t -f DEVICE,TYPE device status | grep ":wifi" | head -n1 | cut -d: -f1)
    
    local eth_details=$(get_interface_details "$eth_interface")
    local wifi_details=$(get_interface_details "$wifi_interface")
    
    # Check for saved decision
    local decision_info=""
    if saved_decision=$(check_saved_decision); then
        decision_info="
🔒 Gespeicherte Entscheidung: $saved_decision"
    fi
    
    local status_text="📊 Aktueller Netzwerk-Status:

🔌 Ethernet ($eth_interface): $eth_status
   └── $eth_details

📶 WiFi ($wifi_interface): $wifi_status
   └── $wifi_details$decision_info"
    
    show_message "Smart WiFi Controller - Status" "$status_text"
}

# Function to show interactive GUI (simplified - no automation)
show_gui() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    
    log_message "INFO" "GUI gestartet - Ethernet: $eth_status, WiFi: $wifi_status"
    
    # Check for saved decision first
    local saved_decision=""
    if saved_decision=$(check_saved_decision); then
        log_message "INFO" "Gespeicherte Entscheidung gefunden: $saved_decision"
        
        if [ "$saved_decision" = "disable_wifi" ] && [ "$eth_status" = "connected" ] && [ "$wifi_status" = "enabled" ]; then
            log_message "INFO" "Führe gespeicherte Entscheidung aus: WiFi deaktivieren"
            manage_connections
            return 0
        elif [ "$saved_decision" = "enable_wifi" ] && [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "disabled" ]; then
            log_message "INFO" "Führe gespeicherte Entscheidung aus: WiFi aktivieren"
            manage_connections
            return 0
        fi
    fi
    
    # Get network interface details
    local eth_interface=$(nmcli -t -f DEVICE,TYPE device status | grep ":ethernet" | head -n1 | cut -d: -f1)
    local wifi_interface=$(nmcli -t -f DEVICE,TYPE device status | grep ":wifi" | head -n1 | cut -d: -f1)
    
    local eth_details=$(get_interface_details "$eth_interface")
    local wifi_details=$(get_interface_details "$wifi_interface")
    
    local action_text=""
    local question=""
    local decision_key=""
    
    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "enabled" ]; then
        question="🔌 Ethernet-Verbindung erkannt und WiFi ist aktiv

📊 Netzwerk-Details:
• Ethernet ($eth_interface): $eth_details
• WiFi ($wifi_interface): $wifi_details

Möchten Sie WiFi deaktivieren?"
        action_text="WiFi deaktivieren"
        decision_key="disable_wifi"
        
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "disabled" ]; then
        question="📡 Keine Ethernet-Verbindung und WiFi ist deaktiviert

📊 Netzwerk-Details:
• Ethernet ($eth_interface): $eth_details
• WiFi ($wifi_interface): $wifi_details

Möchten Sie WiFi aktivieren?"
        action_text="WiFi aktivieren"
        decision_key="enable_wifi"
        
    else
        # Show status with log option
        local status_text="ℹ️ Keine Aktion erforderlich

📊 Aktueller Status:
• Ethernet ($eth_interface): $eth_status - $eth_details
• WiFi ($wifi_interface): $wifi_status - $wifi_details

Möchten Sie die letzten Log-Einträge anzeigen?"
        
        local gui_cmd=$(get_gui_command)
        if [ "$gui_cmd" = "zenity" ]; then
            if zenity --question \
                --title="Smart WiFi Controller" \
                --text="$status_text" \
                --ok-label="Log anzeigen" \
                --cancel-label="Schließen" \
                --width=500 --height=250; then
                show_log_gui
            fi
        else
            if kdialog --yesno "$status_text" --title "Smart WiFi Controller" \
                --yes-label "Log anzeigen" --no-label "Schließen"; then
                show_log_gui
            fi
        fi
        return 0
    fi
    
    # Show GUI question with additional options including "remember decision"
    local gui_cmd=$(get_gui_command)
    local user_choice=""
    
    if [ "$gui_cmd" = "zenity" ]; then
        # Use a simpler approach with info dialog and then question
        zenity --info \
            --title="Smart WiFi Controller" \
            --text="$question" \
            --width=600 --height=400
            
        # Then show the action dialog
        if zenity --question \
            --title="Smart WiFi Controller - Entscheidung" \
            --text="Möchten Sie fortfahren?

Optionen:
• Ja: Aktion jetzt ausführen
• Nein: Abbrechen

Für erweiterte Optionen klicken Sie 'Erweitert'." \
            --width=400 --height=200 \
            --extra-button="Erweitert" \
            --ok-label="Ja" \
            --cancel-label="Nein"; then
            
            user_choice="Ja"
        else
            case $? in
                1)  # Nein
                    user_choice="Nein"
                    ;;
                *)  # Erweitert
                    if zenity --question \
                        --title="Smart WiFi Controller - Erweiterte Optionen" \
                        --text="Möchten Sie diese Entscheidung bis zum nächsten Neustart speichern?

Dies führt die Aktion automatisch bei ähnlichen Situationen aus." \
                        --width=500 --height=200 \
                        --extra-button="Log anzeigen" \
                        --ok-label="Ja, merken und ausführen" \
                        --cancel-label="Nur einmal ausführen"; then
                        
                        user_choice="Ja"
                        save_decision "$decision_key"
                    else
                        case $? in
                            1)  # Nur einmal ausführen
                                user_choice="Ja"
                                ;;
                            *)  # Log anzeigen
                                show_log_gui
                                user_choice="Nein"
                                ;;
                        esac
                    fi
                    ;;
            esac
        fi
    else
        # KDialog fallback - simpler approach
        if kdialog --yesno "$question" --title "Smart WiFi Controller"; then
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
                --title="Smart WiFi Controller" \
                --text="Aktion ausgeführt: $result

Möchten Sie die Log-Einträge anzeigen?" \
                --width=450 \
                --extra-button="Log anzeigen"
            
            if [ $? -ne 0 ]; then
                show_log_gui
            fi
        else
            kdialog --msgbox "Aktion ausgeführt: $result" --title "Smart WiFi Controller"
        fi
        
        log_message "INFO" "Benutzeraktion abgeschlossen"
    else
        log_message "INFO" "Benutzer hat Aktion abgebrochen"
        show_message "Smart WiFi Controller" "Aktion abgebrochen." "info"
    fi
}

# Main script logic
main() {
    # Log script startup
    log_message "INFO" "======================================"
    log_message "INFO" "Smart WiFi Controller Script gestartet"
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
                echo "=== Smart WiFi Controller Log (letzte 15 Einträge) ==="
                get_recent_logs 15
            fi
            ;;
        --manual)
            local result=$(manage_connections)
            echo "$result"
            ;;
        --clear-decision)
            clear_saved_decision
            echo "Gespeicherte Entscheidung wurde gelöscht."
            ;;
        --help|-h)
            cat << EOF
Smart WiFi Controller Script - Intelligente WiFi/Ethernet Verwaltung

Verwendung:
  $0                 Interaktive GUI (Standard)
  $0 --status        Aktuellen Status anzeigen
  $0 --log           Log-Einträge anzeigen (letzte 15)
  $0 --manual        Einmalige manuelle Ausführung (ohne GUI)
  $0 --clear-decision Gespeicherte Entscheidung löschen
  $0 --help          Diese Hilfe anzeigen

Features:
• Intelligente WiFi/Ethernet Verwaltung mit GUI
• IP-Adressen und Geschwindigkeits-Anzeige
• "Entscheidung bis Neustart merken" Option
• Detaillierte Protokollierung aller Aktionen
• Unterstützung für Zenity und KDialog

Das Script überprüft intelligent die Netzwerkverbindungen und bietet
an, WiFi zu deaktivieren (bei Ethernet) oder zu aktivieren (ohne Ethernet).

Log-Datei: $LOG_FILE
Temp-Entscheidung: $TEMP_DECISION_FILE
EOF
            ;;
        *)
            # Default: Show interactive GUI
            check_dependencies
            log_message "INFO" "Smart WiFi Controller gestartet (GUI-Modus)"
            show_gui
            ;;
    esac
}

# Run main function with all arguments
main "$@"