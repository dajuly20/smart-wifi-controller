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

    local timestamp="$(date '+%d. %b %H:%M:%S')"
    local log_entry="$(printf '[%-8s]\t%s\t%s' "$level" "$timestamp" "$message")"

    # Write to log file if LOG_FILE is set
    if [ -n "$LOG_FILE" ]; then
        ensure_log_directory
        echo "$log_entry" >> "$LOG_FILE"
    fi

    # Also display on console with color coding and emojis
    case "$level" in
        "ERROR")
            echo -e "${RED}❌ [ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}⚠️  [WARN]${NC} $message" >&2
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ [SUCCESS]${NC} $message"
            ;;
        "DEBUG")
            echo -e "${BLUE}🔍 [DEBUG]${NC} $message"
            ;;
        *)
            echo -e "${BLUE}ℹ️  [INFO]${NC} $message"
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

    log_message "INFO" "🔍 Überprüfe Systemabhängigkeiten..."

    # Check for NetworkManager
    if ! command -v nmcli &> /dev/null; then
        missing_tools+=("NetworkManager (nmcli)")
        log_message "ERROR" "❌ NetworkManager (nmcli) nicht gefunden"
    else
        log_message "SUCCESS" "✅ NetworkManager verfügbar"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_message "ERROR" "❌ Abhängigkeiten fehlen: ${missing_tools[*]}"
        echo -e "${RED}❌ Fehler: Folgende Tools fehlen:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "  • $tool"
        done
        echo ""
        echo -e "${YELLOW}📦 Installation unter Ubuntu/Debian:${NC}"
        echo "  sudo apt update && sudo apt install network-manager"
        echo ""
        echo -e "${YELLOW}📦 Installation unter Fedora/RHEL:${NC}"
        echo "  sudo dnf install NetworkManager"
        return 1
    fi

    log_message "SUCCESS" "✅ Alle Abhängigkeiten erfüllt"
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

    # Password prompt removed - using plain sudo
    # if [ -n "$SUDO_PASSWORD" ]; then
    #     sudo_cmd="echo '$SUDO_PASSWORD' | sudo -S"
    # fi

    if [ "$action" = "on" ]; then
        log_message "INFO" "📶 Versuche WiFi zu aktivieren..."
        log_message "DEBUG" "   Ausführe: $sudo_cmd nmcli radio wifi on"
        if eval "$sudo_cmd nmcli radio wifi on" 2>/dev/null; then
            log_message "SUCCESS" "✅ WiFi erfolgreich aktiviert"
            return 0
        else
            log_message "ERROR" "❌ Fehler beim Aktivieren von WiFi (nmcli Fehler)"
            return 1
        fi
    elif [ "$action" = "off" ]; then
        log_message "INFO" "📵 Versuche WiFi zu deaktivieren..."
        log_message "DEBUG" "   Ausführe: $sudo_cmd nmcli radio wifi off"
        if eval "$sudo_cmd nmcli radio wifi off" 2>/dev/null; then
            log_message "SUCCESS" "✅ WiFi erfolgreich deaktiviert"
            return 0
        else
            log_message "ERROR" "❌ Fehler beim Deaktivieren von WiFi (nmcli Fehler)"
            return 1
        fi
    else
        log_message "ERROR" "Ungültiger Parameter für toggle_wifi: $action"
        return 1
    fi
}

# Function to show configuration and paths
show_config_info() {
    log_message "DEBUG" "📁 Konfigurationspfade:"
    [ -n "$LOG_FILE" ] && log_message "DEBUG" "   📝 Log-Datei: $LOG_FILE"
    [ -n "$CONFIG_FILE" ] && log_message "DEBUG" "   ⚙️  Konfiguration: $CONFIG_FILE"
    [ -n "$RULES_FILE" ] && log_message "DEBUG" "   📋 Regeln-Datei: $RULES_FILE"
    [ -n "$TEMP_DECISION_FILE" ] && log_message "DEBUG" "   💾 Temp-Entscheidung: $TEMP_DECISION_FILE"
}

# Function to show status with details
show_status_details() {
    local eth_status="$1"
    local wifi_status="$2"

    log_message "DEBUG" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_message "DEBUG" "🔌 Ethernet:  $([ "$eth_status" = "connected" ] && echo '✅ VERBUNDEN' || echo '❌ GETRENNT')"
    log_message "DEBUG" "📶 WiFi:      $([ "$wifi_status" = "on" ] && echo '✅ AN' || echo '❌ AUS')"
    log_message "DEBUG" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Function to check and apply saved decision
check_and_apply_saved_decision() {
    if [ -f "$TEMP_DECISION_FILE" ] 2>/dev/null; then
        local saved=$(cat "$TEMP_DECISION_FILE")
        log_message "INFO" "💾 Gespeicherte Entscheidung gefunden: $saved"
        log_message "DEBUG" "   📂 Pfad: $TEMP_DECISION_FILE"
        log_message "INFO" "   ➜ Wende gespeicherte Entscheidung an..."
        return 0
    fi
    return 1
}

# Function to check and manage network connections
manage_network() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)
    local action_taken=""

    log_message "INFO" "━━━ 🔄 NETZWERK-CHECK GESTARTET ━━━"
    show_status_details "$eth_status" "$wifi_status"
    show_config_info
    echo ""

    # Check if saved decision applies
    check_and_apply_saved_decision

    if [ "$eth_status" = "connected" ] && [ "$wifi_status" = "on" ]; then
        # Ethernet connected and WiFi enabled -> disable WiFi
        log_message "INFO" "🔌 Ethernet verbunden + 📶 WiFi aktiv"
        log_message "INFO" "   → Aktion: WiFi deaktivieren"
        if toggle_wifi "off"; then
            action_taken="✅ WiFi wurde deaktiviert (Ethernet-Verbindung erkannt)"
            log_message "SUCCESS" "$action_taken"
        else
            action_taken="❌ Fehler beim Deaktivieren von WiFi"
            log_message "ERROR" "$action_taken"
        fi
    elif [ "$eth_status" = "disconnected" ] && [ "$wifi_status" = "off" ]; then
        # Ethernet disconnected and WiFi disabled -> enable WiFi
        log_message "INFO" "❌ Ethernet getrennt + 📶 WiFi inaktiv"
        log_message "INFO" "   → Aktion: WiFi aktivieren"
        if toggle_wifi "on"; then
            action_taken="✅ WiFi wurde aktiviert (keine Ethernet-Verbindung)"
            log_message "SUCCESS" "$action_taken"
        else
            action_taken="❌ Fehler beim Aktivieren von WiFi"
            log_message "ERROR" "$action_taken"
        fi
    else
        log_message "INFO" "ℹ️  Keine Aktion erforderlich"
        action_taken="➜ Keine Änderung (Ethernet: $eth_status, WiFi: $wifi_status)"
    fi

    log_message "INFO" "━━━ ✅ NETZWERK-CHECK BEENDET ━━━"
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
