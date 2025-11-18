#!/bin/bash

# Smart WiFi Controller - GUI Prompts
# GUI Dialog Functions for Testing and Integration
# Author: Smart WiFi Controller Team
# Usage: ./smart_wifi_gui_prompts.sh <dialog_name> [parameters...]

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# GUI Detection & Helpers
# ============================================================================

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

# Function to check if GUI is available
is_gui_available() {
    if get_gui_command > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Dialog Functions
# ============================================================================

# Helper function: Show countdown timer dialog
# Shows progress bar with countdown from N seconds, auto-confirms when done
_show_countdown_dialog() {
    local countdown_seconds="${1:-10}"
    local title="${2:-Bestätigung}"
    local message="${3:-Aktion wird ausgeführt...}"
    local gui_cmd=$(get_gui_command)

    if [ "$gui_cmd" != "zenity" ]; then
        # Fallback for non-zenity: just wait and return 0 (confirmed)
        sleep "$countdown_seconds"
        return 0
    fi

    # Create a temporary fifo for progress updates
    local fifo=$(mktemp -u)
    mkfifo "$fifo" 2>/dev/null || fifo="/tmp/countdown_$$"

    # Show progress bar with countdown
    {
        for ((i = countdown_seconds; i > 0; i--)); do
            percent=$(( (countdown_seconds - i) * 100 / countdown_seconds ))
            echo "$percent"
            echo "# WiFi jetzt deaktivieren? ($i Sekunden verbleibend...)"
            sleep 1
        done
        echo "100"
        echo "# Bestätigung automatisch ausgeführt!"
    } | zenity --progress \
        --title="$title" \
        --text="$message" \
        --percentage=0 \
        --width=500 --height=180 \
        --no-cancel \
        --auto-close 2>/dev/null

    rm -f "$fifo" 2>/dev/null
    return 0
}

# ask_disable_wifi <eth_interface> <wlan_interface> <eth_status> <wifi_status> [countdown_seconds]
# Shows confirmation dialog for disabling WiFi when Ethernet is connected
# Includes countdown timer - auto-confirms when timer reaches zero
# Returns: 0 = Ok/Ja (user or auto-confirmed), 1 = Fenster geschlossen/Nein
ask_disable_wifi() {
    local eth_interface="${1:-eth0}"
    local wlan_interface="${2:-wlan0}"
    local eth_status="${3:-connected}"
    local wifi_status="${4:-on}"
    local countdown_seconds="${5:-10}"

    local gui_cmd=$(get_gui_command)
    if [ -z "$gui_cmd" ]; then
        echo -e "${RED}[ERROR]${NC} Keine GUI verfügbar"
        return 1
    fi

    # Format the message with network details at the top (larger)
    local message="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔌 Ethernet [$eth_interface]: $eth_status
📶 WiFi [$wlan_interface]: $wifi_status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WiFi sollte deaktiviert werden

WiFi jetzt deaktivieren?"

    if [ "$gui_cmd" = "zenity" ]; then
        # Use an info dialog with timeout for auto-confirmation
        # Only OK button (press Escape to cancel)
        # If user doesn't respond in countdown_seconds, auto-confirm (return 0)
        timeout --signal=KILL "$countdown_seconds" zenity --info \
            --title="Smart WiFi Controller" \
            --text="$message" \
            --width=500 --height=250 \
            --ok-label="✅ OK (${countdown_seconds}s)" 2>/dev/null

        local result=$?
        if [ $result -eq 124 ]; then
            # Timeout - auto-confirm
            echo -e "${GREEN}[INFO]${NC} Countdown abgelaufen - Aktion automatisch bestätigt"
            return 0
        elif [ $result -eq 0 ]; then
            # User clicked OK
            return 0
        else
            # User pressed Escape
            return 1
        fi

    elif [ "$gui_cmd" = "kdialog" ]; then
        # KDialog fallback - simple msgbox
        kdialog --msgbox "$message" --title "Smart WiFi Controller"
        return $?
    fi
}

# ask_enable_wifi <eth_interface> <wlan_interface> <eth_status> <wifi_status> [countdown_seconds]
# Shows confirmation dialog for enabling WiFi when Ethernet is disconnected
# Includes countdown timer - auto-confirms when timer reaches zero
# Returns: 0 = Ok/Ja (user or auto-confirmed), 1 = Fenster geschlossen/Nein
ask_enable_wifi() {
    local eth_interface="${1:-eth0}"
    local wlan_interface="${2:-wlan0}"
    local eth_status="${3:-disconnected}"
    local wifi_status="${4:-off}"
    local countdown_seconds="${5:-10}"

    local gui_cmd=$(get_gui_command)
    if [ -z "$gui_cmd" ]; then
        echo -e "${RED}[ERROR]${NC} Keine GUI verfügbar"
        return 1
    fi

    # Format the message with network details at the top (larger)
    local message="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔌 Ethernet [$eth_interface]: $eth_status
📶 WiFi [$wlan_interface]: $wifi_status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WiFi sollte aktiviert werden

WiFi jetzt aktivieren?"

    if [ "$gui_cmd" = "zenity" ]; then
        # Use an info dialog with timeout for auto-confirmation
        # Only OK button (press Escape to cancel)
        # If user doesn't respond in countdown_seconds, auto-confirm (return 0)
        timeout --signal=KILL "$countdown_seconds" zenity --info \
            --title="Smart WiFi Controller" \
            --text="$message" \
            --width=500 --height=250 \
            --ok-label="✅ OK (${countdown_seconds}s)" 2>/dev/null

        local result=$?
        if [ $result -eq 124 ]; then
            # Timeout - auto-confirm
            echo -e "${GREEN}[INFO]${NC} Countdown abgelaufen - Aktion automatisch bestätigt"
            return 0
        elif [ $result -eq 0 ]; then
            # User clicked OK
            return 0
        else
            # User pressed Escape
            return 1
        fi

    elif [ "$gui_cmd" = "kdialog" ]; then
        # KDialog fallback - simple msgbox
        kdialog --msgbox "$message" --title "Smart WiFi Controller"
        return $?
    fi
}

# show_info <title> <message>
# Shows an info message dialog
show_info() {
    local title="${1:-Smart WiFi Controller}"
    local message="${2:-Info Message}"

    local gui_cmd=$(get_gui_command)
    if [ -z "$gui_cmd" ]; then
        echo -e "${RED}[ERROR]${NC} Keine GUI verfügbar"
        return 1
    fi

    if [ "$gui_cmd" = "zenity" ]; then
        zenity --info --title="$title" --text="$message" --width=400
    elif [ "$gui_cmd" = "kdialog" ]; then
        kdialog --msgbox "$message" --title "$title"
    fi
}

# show_warning <title> <message>
# Shows a warning message dialog
show_warning() {
    local title="${1:-Smart WiFi Controller}"
    local message="${2:-Warning Message}"

    local gui_cmd=$(get_gui_command)
    if [ -z "$gui_cmd" ]; then
        echo -e "${RED}[ERROR]${NC} Keine GUI verfügbar"
        return 1
    fi

    if [ "$gui_cmd" = "zenity" ]; then
        zenity --warning --title="$title" --text="$message" --width=400
    elif [ "$gui_cmd" = "kdialog" ]; then
        kdialog --sorry "$message" --title "$title"
    fi
}

# show_error <title> <message>
# Shows an error message dialog
show_error() {
    local title="${1:-Smart WiFi Controller}"
    local message="${2:-Error Message}"

    local gui_cmd=$(get_gui_command)
    if [ -z "$gui_cmd" ]; then
        echo -e "${RED}[ERROR]${NC} Keine GUI verfügbar"
        return 1
    fi

    if [ "$gui_cmd" = "zenity" ]; then
        zenity --error --title="$title" --text="$message" --width=400
    elif [ "$gui_cmd" = "kdialog" ]; then
        kdialog --error "$message" --title "$title"
    fi
}

# ============================================================================
# Help Function
# ============================================================================

show_help() {
    cat << 'EOF'
Smart WiFi Controller - GUI Prompts Test Tool

Verwendung:
  ./smart_wifi_gui_prompts.sh <dialog> [parameters...]

Verfügbare Dialoge:

  ask_disable_wifi [eth_if] [wlan_if] [eth_status] [wifi_status]
    Zeigt Dialog zum Deaktivieren von WiFi
    Button: 📵 Ja (WiFi durchgestrichenem Emoji)
    Returns: 0 = Ok/Ja, 1 = Fenster geschlossen/Nein
    Parameter (optional):
      eth_if      - Ethernet Interface (Standard: eth0)
      wlan_if     - WiFi Interface (Standard: wlan0)
      eth_status  - Ethernet Status (Standard: connected)
      wifi_status - WiFi Status (Standard: on)

  ask_enable_wifi [eth_if] [wlan_if] [eth_status] [wifi_status]
    Zeigt Dialog zum Aktivieren von WiFi
    Button: 📶 Ja (WiFi Emoji)
    Returns: 0 = Ok/Ja, 1 = Fenster geschlossen/Nein
    Parameter (optional):
      eth_if      - Ethernet Interface (Standard: eth0)
      wlan_if     - WiFi Interface (Standard: wlan0)
      eth_status  - Ethernet Status (Standard: disconnected)
      wifi_status - WiFi Status (Standard: off)

  show_info [title] [message]
    Zeigt Info-Dialog
    Parameter (optional):
      title   - Dialog Titel
      message - Dialog Nachricht

  show_warning [title] [message]
    Zeigt Warnungs-Dialog

  show_error [title] [message]
    Zeigt Fehler-Dialog

  check
    Prüft ob GUI verfügbar ist

  help
    Zeigt diese Hilfe an

Beispiele:

  # Standard Disable-Dialog (WiFi deaktivieren mit 📵 Button)
  ./smart_wifi_gui_prompts.sh ask_disable_wifi

  # Custom Interfaces für Disable
  ./smart_wifi_gui_prompts.sh ask_disable_wifi enp0s3 wlan0 connected on

  # Standard Enable-Dialog (WiFi aktivieren mit 📶 Button)
  ./smart_wifi_gui_prompts.sh ask_enable_wifi

  # Custom Interfaces für Enable
  ./smart_wifi_gui_prompts.sh ask_enable_wifi eth0 wlan0 disconnected off

  # Mit Exit-Code arbeiten
  ./smart_wifi_gui_prompts.sh ask_disable_wifi
  if [ $? -eq 0 ]; then
    echo "Benutzer klickte Ok - Aktion ausführen"
  else
    echo "Benutzer lehnte ab - keine Aktion"
  fi

  # Info Dialog
  ./smart_wifi_gui_prompts.sh show_info "Titel" "Nachricht"

  # Prüfe GUI-Verfügbarkeit
  ./smart_wifi_gui_prompts.sh check

EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local dialog="${1:-help}"

    case "$dialog" in
        ask_disable_wifi)
            ask_disable_wifi "$2" "$3" "$4" "$5"
            local result=$?
            if [ $result -eq 0 ]; then
                echo -e "${GREEN}[RESULT]${NC} Benutzer klickte: Ok/Ja"
            else
                echo -e "${YELLOW}[RESULT]${NC} Benutzer lehnte ab (Fenster geschlossen)"
            fi
            return $result
            ;;
        ask_enable_wifi)
            ask_enable_wifi "$2" "$3" "$4" "$5"
            local result=$?
            if [ $result -eq 0 ]; then
                echo -e "${GREEN}[RESULT]${NC} Benutzer klickte: Ok/Ja"
            else
                echo -e "${YELLOW}[RESULT]${NC} Benutzer lehnte ab (Fenster geschlossen)"
            fi
            return $result
            ;;
        show_info)
            show_info "$2" "$3"
            ;;
        show_warning)
            show_warning "$2" "$3"
            ;;
        show_error)
            show_error "$2" "$3"
            ;;
        check)
            if is_gui_available; then
                local gui_cmd=$(get_gui_command)
                echo -e "${GREEN}[OK]${NC} GUI verfügbar: $gui_cmd"
                return 0
            else
                echo -e "${RED}[ERROR]${NC} Keine GUI verfügbar"
                echo "Installation erforderlich:"
                echo "  Ubuntu/Debian: sudo apt install zenity"
                echo "  Fedora/RHEL:   sudo dnf install zenity"
                return 1
            fi
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unbekannter Dialog: $dialog"
            echo ""
            show_help
            return 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
