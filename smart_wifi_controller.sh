#!/bin/bash

# Smart WiFi Controller Script with GUI (Single-Run Mode)
# Intelligently manages WiFi based on Ethernet connection status - single execution only
# Author: Smart WiFi Controller Script
# Date: $(date)

# Set log file before sourcing core
LOG_FILE="$HOME/.local/share/smart_wifi_controller/smart_wifi_controller.log"

# Function to get GUI password if sudo is required
ask_password_gui() {
    local gui_cmd=""

    # Detect which GUI tool is available
    if command -v zenity &> /dev/null; then
        gui_cmd="zenity"
    elif command -v kdialog &> /dev/null; then
        gui_cmd="kdialog"
    else
        return 1  # No GUI available, let sudo handle it
    fi

    # Ask for password
    if [ "$gui_cmd" = "zenity" ]; then
        zenity --password --title="Smart WiFi Controller" \
            --text="Dieses Programm benötigt Administrator-Rechte.\nBitte geben Sie Ihr Passwort ein:"
    else
        kdialog --password "Passwort erforderlich für Smart WiFi Controller:"
    fi
}

# Check if we need sudo and handle password
export SUDO_ASKPASS_HELPER=1
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    # We need sudo and don't have passwordless sudo configured
    password=$(ask_password_gui)
    if [ $? -ne 0 ] || [ -z "$password" ]; then
        echo "Passwort erforderlich. Abbruch."
        exit 1
    fi
    # Export password for sudo -S
    export SUDO_PASSWORD="$password"
fi

# Source the core logic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/smart_wifi_core.sh" ]; then
    source "$SCRIPT_DIR/smart_wifi_core.sh"
else
    echo "Error: smart_wifi_core.sh not found!"
    exit 1
fi

# Configuration file for settings (simplified - not used in single-run mode)
CONFIG_FILE="$HOME/.config/smart_wifi_controller_config"

# Temporary decision file (until reboot)
TEMP_DECISION_FILE="/tmp/smart_wifi_controller_decision"

# Function to check if required tools are installed (extended version for GUI)
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
        return 1
    fi

    log_message "SUCCESS" "Alle Abhängigkeiten erfüllt"
    return 0
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
    # Normalize output: "enabled" -> "on", "disabled" -> "off"
    case "$wifi_state" in
        "enabled")
            echo "on"
            ;;
        "disabled")
            echo "off"
            ;;
        *)
            echo "$wifi_state"
            ;;
    esac
}

# Function to enable/disable WiFi
toggle_wifi() {
    local action="$1" # on or off
    local sudo_cmd="sudo"

    # Use password if available
    if [ -n "$SUDO_PASSWORD" ]; then
        sudo_cmd="echo '$SUDO_PASSWORD' | sudo -S"
    fi

    if [ "$action" = "on" ]; then
        log_message "INFO" "Versuche WiFi zu aktivieren..."
        if eval "$sudo_cmd nmcli radio wifi on" 2>/dev/null; then
            log_message "SUCCESS" "WiFi erfolgreich aktiviert"
            return 0
        else
            log_message "ERROR" "Fehler beim Aktivieren von WiFi"
            return 1
        fi
    elif [ "$action" = "off" ]; then
        log_message "INFO" "Versuche WiFi zu deaktivieren..."
        if eval "$sudo_cmd nmcli radio wifi off" 2>/dev/null; then
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

# Wrapper for compatibility with core logic
manage_connections() {
    manage_network
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
        
        if [ "$saved_decision" = "disable_wifi" ] && [ "$eth_status" = "connected" ] && [ "$wifi_status" = "on" ]; then
            log_message "INFO" "Führe gespeicherte Entscheidung aus: WiFi deaktivieren"
            manage_connections
            return 0
        elif [ "$saved_decision" = "enable_wifi" ] && [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "off" ]; then
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
    
    local check_interval="5 Sekunden"  # From daemon.sh sleep interval

    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "on" ]; then
        question="🔌 Ethernet-Verbindung erkannt und WiFi ist aktiv

📊 Netzwerk-Details:
• Ethernet ($eth_interface): $eth_details
• WiFi ($wifi_interface): $wifi_details

⏱️  Nächste Prüfung: $check_interval

Möchten Sie WiFi deaktivieren?"
        action_text="WiFi deaktivieren"
        decision_key="disable_wifi"
        
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "off" ]; then
        question="📡 Keine Ethernet-Verbindung und WiFi ist deaktiviert

📊 Netzwerk-Details:
• Ethernet ($eth_interface): $eth_details
• WiFi ($wifi_interface): $wifi_details

⏱️  Nächste Prüfung: $check_interval

Möchten Sie WiFi aktivieren?"
        action_text="WiFi aktivieren"
        decision_key="enable_wifi"
        
    else
        # Show status with log option
        local status_text="ℹ️ Keine Aktion erforderlich

📊 Aktueller Status:
• Ethernet ($eth_interface): $eth_status - $eth_details
• WiFi ($wifi_interface): $wifi_status - $wifi_details

⏱️  Nächste Prüfung: $check_interval

Möchten Sie die letzten Log-Einträge anzeigen?"
        
        local gui_cmd=$(get_gui_command)
        if [ "$gui_cmd" = "zenity" ]; then
            if zenity --question \
                --title="Smart WiFi Controller" \
                --text="$status_text" \
                --ok-label="Log anzeigen" \
                --cancel-label="Schließen" \
                --width=500 --height=280; then
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
    
    # Show GUI with new button logic: Ja (mit Speichern), Nein (ohne Speichern), Abrechen
    local gui_cmd=$(get_gui_command)
    local user_choice=""

    if [ "$gui_cmd" = "zenity" ]; then
        # Show single dialog with all options
        zenity --question \
            --title="Smart WiFi Controller" \
            --text="$question

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Wie möchten Sie fortfahren?

• Ja: Entscheidung speichern & $action_text
• Nein: $action_text (ohne Speicherung)
• Abrechen: Aktion abbrechen" \
            --width=600 --height=350 \
            --ok-label="Ja" \
            --cancel-label="Abrechen" \
            --extra-button="Nein"

        local result=$?
        case $result in
            0)  # Ja - mit Speichern
                user_choice="Ja_mit_speichern"
                ;;
            1)  # Abrechen
                user_choice="Abrechen"
                ;;
            *)  # Nein - ohne Speichern
                user_choice="Ja_ohne_speichern"
                ;;
        esac
    else
        # KDialog fallback - 2 buttons (Ja mit speichern, Abrechen) + separate Nein-Option
        kdialog --yesno "$question

Ja = speichern & $action_text
Nein = Abrechen" --title "Smart WiFi Controller" \
            --yes-label "Ja (speichern)" --no-label "Abrechen"

        if [ $? -eq 0 ]; then
            user_choice="Ja_mit_speichern"
        else
            user_choice="Abrechen"
        fi
    fi
    
    # Process user choice
    case "$user_choice" in
        "Ja_mit_speichern")
            # Execute action and save decision
            save_decision "$decision_key"
            local result=$(manage_connections)

            if [ "$gui_cmd" = "zenity" ]; then
                zenity --info \
                    --title="Smart WiFi Controller" \
                    --text="✅ Aktion ausgeführt und Entscheidung gespeichert!

$result

Die Entscheidung wird bis zur nächsten Netzwerkänderung beibehalten." \
                    --width=450 --height=180
            else
                kdialog --msgbox "Aktion ausgeführt (gespeichert): $result" --title "Smart WiFi Controller"
            fi

            log_message "INFO" "Benutzeraktion ausgeführt und Entscheidung gespeichert"
            ;;

        "Ja_ohne_speichern")
            # Execute action WITHOUT saving decision
            local result=$(manage_connections)

            if [ "$gui_cmd" = "zenity" ]; then
                zenity --info \
                    --title="Smart WiFi Controller" \
                    --text="✅ Aktion ausgeführt (nicht gespeichert)

$result

Die Entscheidung wird nicht beibehalten - nächste Prüfung läuft normal." \
                    --width=450 --height=180
            else
                kdialog --msgbox "Aktion ausgeführt (nicht gespeichert): $result" --title "Smart WiFi Controller"
            fi

            log_message "INFO" "Benutzeraktion ausgeführt ohne zu speichern"
            ;;

        "Abrechen")
            log_message "INFO" "Benutzer hat Aktion abgebrochen"
            show_message "Smart WiFi Controller" "Aktion abgebrochen." "info"
            ;;
    esac
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