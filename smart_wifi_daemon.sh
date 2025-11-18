#!/bin/bash

# Smart WiFi Controller Daemon
# Kontinuierliche Überwachung von WiFi/Ethernet mit System Tray Icon
# Author: Smart WiFi Controller Team

# Configuration
CONFIG_DIR="$HOME/.config/smart_wifi_controller"
LOG_FILE="$HOME/.local/share/smart_wifi_controller/daemon.log"
PID_FILE="$CONFIG_DIR/daemon.pid"
TRAY_ICON_DIR="$CONFIG_DIR/icons"

# Source the core logic
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/smart_wifi_core.sh" ]; then
    source "$SCRIPT_DIR/smart_wifi_core.sh"
else
    echo "Error: smart_wifi_core.sh not found!"
    exit 1
fi

# Ensure directories exist
ensure_directories() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$TRAY_ICON_DIR"
}

# Create system tray icon file for the daemon
create_tray_icon_script() {
    cat > "$TRAY_ICON_DIR/tray_icon.py" << 'PYTHON_EOF'
#!/usr/bin/env python3

import sys
import os
import signal
import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')

from gi.repository import Gtk, AppIndicator3, GLib
import subprocess
import psutil

class SmartWiFiIndicator:
    def __init__(self):
        self.config_dir = os.path.expanduser('~/.config/smart_wifi_controller')
        self.status_file = os.path.join(self.config_dir, 'daemon_status')
        self.pid_file = os.path.join(self.config_dir, 'daemon.pid')

        # Create indicator
        self.indicator = AppIndicator3.Indicator.new(
            "smart-wifi-controller",
            os.path.join(self.config_dir, 'icons', 'icon.svg'),
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

        # Build menu
        self.menu = self.build_menu()
        self.indicator.set_menu(self.menu)

        # Update status periodically
        GLib.timeout_add_seconds(2, self.update_status)

    def build_menu(self):
        menu = Gtk.Menu()

        # Status item
        self.status_item = Gtk.MenuItem(label="Status: Prüfe...")
        menu.append(self.status_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Open logs
        logs_item = Gtk.MenuItem(label="Logs anzeigen")
        logs_item.connect("activate", self.show_logs)
        menu.append(logs_item)

        # Stop daemon
        stop_item = Gtk.MenuItem(label="Daemon stoppen")
        stop_item.connect("activate", self.stop_daemon)
        menu.append(stop_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Quit
        quit_item = Gtk.MenuItem(label="Beenden")
        quit_item.connect("activate", self.quit_application)
        menu.append(quit_item)

        menu.show_all()
        return menu

    def update_status(self):
        try:
            # Read status from daemon
            if os.path.exists(self.status_file):
                with open(self.status_file, 'r') as f:
                    status = f.read().strip()
            else:
                status = "Inaktiv"

            # Check if daemon is running
            daemon_running = False
            if os.path.exists(self.pid_file):
                with open(self.pid_file, 'r') as f:
                    pid = int(f.read().strip())
                    try:
                        daemon_running = psutil.pid_exists(pid)
                    except:
                        daemon_running = False

            if daemon_running:
                self.status_item.set_label(f"Status: {status}")
            else:
                self.status_item.set_label("Status: Daemon läuft nicht")
        except Exception as e:
            self.status_item.set_label(f"Status: Fehler ({str(e)[:20]})")

        return True

    def show_logs(self, widget):
        log_file = os.path.expanduser('~/.local/share/smart_wifi_controller/daemon.log')
        subprocess.Popen(['xdg-open', log_file])

    def stop_daemon(self, widget):
        try:
            if os.path.exists(self.pid_file):
                with open(self.pid_file, 'r') as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGTERM)
        except Exception as e:
            print(f"Error stopping daemon: {e}")

    def quit_application(self, widget):
        Gtk.main_quit()

if __name__ == "__main__":
    indicator = SmartWiFiIndicator()
    signal.signal(signal.SIGINT, lambda s, f: Gtk.main_quit())
    Gtk.main()
PYTHON_EOF
    chmod +x "$TRAY_ICON_DIR/tray_icon.py"
}

# Create simple SVG icon
create_tray_icon() {
    cat > "$TRAY_ICON_DIR/icon.svg" << 'SVG_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <!-- WiFi icon with active indicator -->
  <defs>
    <style>
      .wifi-active { fill: #00AA00; }
      .wifi-idle { fill: #666666; }
    </style>
  </defs>

  <!-- WiFi curves -->
  <path class="wifi-idle" d="M 12 8 Q 16 8 19 11 L 17.5 12.5 Q 15 10 12 10 Q 9 10 6.5 12.5 L 5 11 Q 8 8 12 8 Z"/>
  <path class="wifi-idle" d="M 12 13 Q 15.5 13 18 15.5 L 16 17.5 Q 14 16 12 16 Q 10 16 8 17.5 L 6 15.5 Q 8.5 13 12 13 Z"/>

  <!-- Signal dot -->
  <circle class="wifi-active" cx="12" cy="21" r="2"/>
</svg>
SVG_EOF
}

# Update daemon status display based on current network status
update_daemon_status_display() {
    local eth_status=$(get_ethernet_status)
    local wifi_status=$(get_wifi_status)

    local status_text="WiFi: "
    [ "$wifi_status" = "on" ] && status_text="${status_text}AN" || status_text="${status_text}AUS"
    status_text="$status_text | Ethernet: "
    [ "$eth_status" = "connected" ] && status_text="${status_text}AN" || status_text="${status_text}AUS"

    update_status "$status_text"
}

# Update daemon status file (for tray icon)
update_status() {
    echo "$1" > "$CONFIG_DIR/daemon_status"
}

# Save PID
save_pid() {
    echo $$ > "$PID_FILE"
}

# Clean up on exit
cleanup() {
    log_message "INFO" "Daemon wird beendet..."
    rm -f "$PID_FILE"
    rm -f "$CONFIG_DIR/daemon_status"
    exit 0
}

# Main daemon loop
main() {
    ensure_directories
    create_tray_icon
    create_tray_icon_script
    save_pid

    log_message "SUCCESS" "Smart WiFi Controller Daemon gestartet (PID: $$)"
    update_status "Initialisierung..."

    # Trap signals for clean shutdown
    trap cleanup SIGTERM SIGINT

    # Main loop - check every 5 seconds
    while true; do
        manage_network > /dev/null 2>&1
        update_daemon_status_display
        sleep 5
    done
}

# Run main function
main
