#!/bin/bash

# Smart WiFi Controller - Condition Evaluation Engine
# Evaluates and applies WiFi management rules
# Author: Smart WiFi Controller Team

# ============================================================================
# Condition Evaluation Functions
# ============================================================================

# Function to evaluate a condition and return true/false
# Returns: 0 (true) if condition is met, 1 (false) otherwise
evaluate_condition() {
    local condition="$1"

    case "$condition" in
        "NOT (any eth connected)")
            # True if NO ethernet is connected
            if [ "$(get_ethernet_status)" = "disconnected" ]; then
                return 0  # true
            else
                return 1  # false
            fi
            ;;
        "(any eth connected)")
            # True if ethernet IS connected
            if [ "$(get_ethernet_status)" = "connected" ]; then
                return 0  # true
            else
                return 1  # false
            fi
            ;;
        "always on")
            return 0  # always true
            ;;
        "always off")
            return 1  # always false
            ;;
        *)
            log_message "WARN" "Unbekannte Bedingung: $condition"
            return 1
            ;;
    esac
}

# Function to check if WiFi should be enabled based on condition
should_wifi_be_enabled() {
    local condition="$1"

    if evaluate_condition "$condition"; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to apply a single rule
apply_rule() {
    local interface="$1"
    local condition="$2"

    log_message "INFO" "Evaluiere Rule: [$interface] = $condition"

    # Evaluate condition
    local should_enable=$(should_wifi_be_enabled "$condition")

    # Get current WiFi status
    local current_status=$(nmcli radio wifi 2>/dev/null)
    local current_enabled=false
    if [ "$current_status" = "enabled" ]; then
        current_enabled=true
    fi

    # Apply rule if status should change
    if [ "$should_enable" = "true" ] && [ "$current_enabled" = false ]; then
        log_message "INFO" "Regel anwenden: [$interface] AKTIVIEREN (Bedingung: $condition)"
        toggle_wifi "on"
        return 0
    elif [ "$should_enable" = "false" ] && [ "$current_enabled" = true ]; then
        log_message "INFO" "Regel anwenden: [$interface] DEAKTIVIEREN (Bedingung: $condition)"
        toggle_wifi "off"
        return 0
    else
        log_message "DEBUG" "Keine Änderung nötig für [$interface]"
        return 0
    fi
}
