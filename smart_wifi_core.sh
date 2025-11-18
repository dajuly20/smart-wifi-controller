#!/bin/bash

# Smart WiFi Controller - Core Logic
# Shared logic for both manual execution and daemon
# Author: Smart WiFi Controller Team

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages with different levels
log_message() {
    local level="${1:-INFO}"
    local message="$2"

    # If only one parameter is provided, treat it as INFO level message
    if [ -z "$message" ]; then
        message="$level"
        level="INFO"
    fi

    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[$timestamp] [$level] $message"

    # Write to log file if LOG_FILE is set
    if [ -n "$LOG_FILE" ]; then
        ensure_log_directory
        echo "$log_entry" >> "$LOG_FILE"
    fi

    # Also display on console with color coding
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        *)
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

# Function to ensure log directory exists
ensure_log_directory() {
    if [ -n "$LOG_FILE" ]; then
        local log_dir=$(dirname "$LOG_FILE")
        if [ ! -d "$log_dir" ]; then
            mkdir -p "$log_dir"
        fi
    fi
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

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_message "ERROR" "Abhängigkeiten fehlen: ${missing_tools[*]}"
        echo -e "${RED}Fehler: Folgende Tools fehlen:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Installation unter Ubuntu/Debian:"
        echo "sudo apt update && sudo apt install network-manager"
        echo ""
        echo "Installation unter Fedora/RHEL:"
        echo "sudo dnf install NetworkManager"
        return 1
    fi

    log_message "SUCCESS" "Alle Abhängigkeiten erfüllt"
    return 0
}

# Function to get network interface status
get_ethernet_status() {
    # Get all ethernet connections that are up
    local eth_connections=$(nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ethernet | grep activated)
    if [ -n "$eth_connections" ]; then
        echo "connected"
    else
        echo "disconnected"
    fi
}

# Function to get WiFi status
get_wifi_status() {
    local wifi_state=$(nmcli radio wifi 2>/dev/null)
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

# Function to check and manage network connections
manage_network() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    local action_taken=""

    log_message "INFO" "=== Netzwerk-Check gestartet ==="
    log_message "INFO" "Ethernet Status: $eth_status"
    log_message "INFO" "WiFi Status: $wifi_status"

    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "on" ]; then
        # Ethernet connected and WiFi enabled -> disable WiFi
        log_message "INFO" "Ethernet verbunden und WiFi aktiv - deaktiviere WiFi"
        if toggle_wifi "off"; then
            action_taken="WiFi wurde deaktiviert (Ethernet-Verbindung erkannt)"
            log_message "SUCCESS" "$action_taken"
        else
            action_taken="Fehler beim Deaktivieren von WiFi"
            log_message "ERROR" "$action_taken"
        fi
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "off" ]; then
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

# Function to get the last N log entries
get_recent_logs() {
    local num_entries="${1:-15}"

    if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
        tail -n "$num_entries" "$LOG_FILE"
    else
        echo "Keine Log-Einträge vorhanden."
    fi
}
