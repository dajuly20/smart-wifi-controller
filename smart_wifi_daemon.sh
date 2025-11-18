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
    # Log loaded file
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(printf '[%-8s]\t%s\t%s' 'INFO' "$(date '+%d. %b %H:%M:%S')" "Datei geladen: $SCRIPT_DIR/smart_wifi_core.sh")" >> "$LOG_FILE"
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
import subprocess
import psutil

# Self-elevate if not running with sudo
if os.geteuid() != 0:
    # Re-run script with sudo
    args = ['sudo', sys.executable] + sys.argv
    os.execlp('sudo', 'sudo', sys.executable, *sys.argv)

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')

from gi.repository import Gtk, AppIndicator3, GLib

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

        # Status sections
        self.ethernet_item = Gtk.MenuItem(label="🔌 Ethernet: Prüfe...")
        menu.append(self.ethernet_item)

        self.wifi_item = Gtk.MenuItem(label="📶 WiFi: Prüfe...")
        menu.append(self.wifi_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Quick actions
        self.wifi_toggle = Gtk.MenuItem(label="📶 WiFi aktivieren")
        self.wifi_toggle.connect("activate", self.toggle_wifi_quick)
        menu.append(self.wifi_toggle)

        menu.append(Gtk.SeparatorMenuItem())

        # Saved decision
        self.decision_item = Gtk.MenuItem(label="💾 Gespeicherte Entscheidung: Keine")
        self.decision_item.connect("activate", self.show_saved_decision)
        menu.append(self.decision_item)

        # Reload rules
        reload_item = Gtk.MenuItem(label="🔄 Regeln neu laden")
        reload_item.connect("activate", self.reload_rules)
        menu.append(reload_item)

        # Open logs
        logs_item = Gtk.MenuItem(label="📋 Logs anzeigen")
        logs_item.connect("activate", self.show_logs)
        menu.append(logs_item)

        # Daemon info
        info_item = Gtk.MenuItem(label="ℹ️  Daemon Info")
        info_item.connect("activate", self.show_daemon_info)
        menu.append(info_item)

        menu.append(Gtk.SeparatorMenuItem())

        # Stop daemon
        stop_item = Gtk.MenuItem(label="⛔ Daemon stoppen")
        stop_item.connect("activate", self.stop_daemon)
        menu.append(stop_item)

        # Quit tray icon
        quit_item = Gtk.MenuItem(label="❌ Tray Icon beenden")
        quit_item.connect("activate", self.quit_application)
        menu.append(quit_item)

        menu.show_all()
        return menu

    def get_ethernet_status(self):
        """Get Ethernet status using nmcli"""
        try:
            result = subprocess.run(
                "nmcli -t -f NAME,TYPE,STATE connection show --active 2>/dev/null | grep ethernet | grep activated",
                shell=True, capture_output=True, text=True, timeout=5
            )
            return "verbunden" if result.returncode == 0 else "getrennt"
        except:
            return "Fehler"

    def get_wifi_status(self):
        """Get WiFi status using nmcli"""
        try:
            result = subprocess.run(
                "nmcli radio wifi 2>/dev/null",
                shell=True, capture_output=True, text=True, timeout=5
            )
            status = result.stdout.strip().lower()
            return "AN" if status == "enabled" else "AUS"
        except:
            return "Fehler"

    def get_saved_decision(self):
        """Get saved decision from temp file"""
        decision_file = "/tmp/smart_wifi_controller_decision"
        if os.path.exists(decision_file):
            try:
                with open(decision_file, 'r') as f:
                    decision = f.read().strip()
                    if decision == "disable_wifi":
                        return "WiFi deaktivieren"
                    elif decision == "enable_wifi":
                        return "WiFi aktivieren"
            except:
                pass
        return None

    def update_status(self):
        try:
            # Get actual network status
            eth_status = self.get_ethernet_status()
            wifi_status = self.get_wifi_status()

            # Update status items
            eth_emoji = "✅" if eth_status == "verbunden" else "❌"
            wifi_emoji = "✅" if wifi_status == "AN" else "❌"

            self.ethernet_item.set_label(f"🔌 Ethernet: {eth_emoji} {eth_status.upper()}")
            self.wifi_item.set_label(f"📶 WiFi: {wifi_emoji} {wifi_status}")

            # Update WiFi toggle label
            if wifi_status == "AN":
                self.wifi_toggle.set_label("📵 WiFi deaktivieren")
            else:
                self.wifi_toggle.set_label("📶 WiFi aktivieren")

            # Update saved decision display
            saved_decision = self.get_saved_decision()
            if saved_decision:
                self.decision_item.set_label(f"💾 Gespeicherte Entscheidung: {saved_decision}")
            else:
                self.decision_item.set_label("💾 Gespeicherte Entscheidung: Keine")

            # Check if daemon is running
            daemon_running = False
            if os.path.exists(self.pid_file):
                try:
                    with open(self.pid_file, 'r') as f:
                        pid = int(f.read().strip())
                        daemon_running = psutil.pid_exists(pid)
                except:
                    daemon_running = False

            # Update indicator icon based on WiFi status
            if not daemon_running:
                self.indicator.set_status(AppIndicator3.IndicatorStatus.ATTENTION)
            else:
                self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

        except Exception as e:
            print(f"Error updating status: {e}")

        return True

    def show_saved_decision(self, widget):
        """Show and manage saved decision"""
        decision_file = "/tmp/smart_wifi_controller_decision"
        saved_decision = self.get_saved_decision()

        if saved_decision:
            dialog = Gtk.MessageDialog(
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.YES_NO,
                message_format="Gespeicherte Entscheidung"
            )
            dialog.format_secondary_text(f"Aktuelle Entscheidung: {saved_decision}\n\nMöchtest du diese löschen?")
            response = dialog.run()
            dialog.destroy()

            if response == Gtk.ResponseType.YES:
                try:
                    os.remove(decision_file)
                    print("Entscheidung gelöscht")
                    GLib.idle_add(self.update_status)
                except:
                    pass
        else:
            dialog = Gtk.MessageDialog(
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                message_format="Keine Entscheidung gespeichert"
            )
            dialog.format_secondary_text("Es gibt keine gespeicherte Entscheidung.")
            dialog.run()
            dialog.destroy()

    def toggle_wifi_quick(self, widget):
        """Quick toggle WiFi on/off"""
        try:
            current_status = self.get_wifi_status()
            if current_status == "AN":
                subprocess.run(["nmcli", "radio", "wifi", "off"], timeout=5)
            else:
                subprocess.run(["nmcli", "radio", "wifi", "on"], timeout=5)
            GLib.idle_add(self.update_status)
        except Exception as e:
            print(f"Error toggling WiFi: {e}")

    def reload_rules(self, widget):
        """Reload rules by signaling daemon"""
        try:
            if os.path.exists(self.pid_file):
                with open(self.pid_file, 'r') as f:
                    pid = int(f.read().strip())
                os.kill(pid, signal.SIGUSR1)
                print("Regeln neu geladen")
        except Exception as e:
            print(f"Error reloading rules: {e}")

    def show_daemon_info(self, widget):
        """Show daemon information dialog"""
        try:
            config_dir = os.path.expanduser('~/.config/smart_wifi_controller')
            log_dir = os.path.expanduser('~/.local/share/smart_wifi_controller')
            daemon_log = os.path.join(log_dir, 'daemon.log')

            last_logs = "Keine Logs"
            if os.path.exists(daemon_log):
                try:
                    result = subprocess.run(
                        f"tail -n 3 {daemon_log}",
                        shell=True, capture_output=True, text=True, timeout=5
                    )
                    if result.stdout:
                        last_logs = result.stdout.strip()
                except:
                    pass

            info_text = f"Config: {config_dir}\\nLogs: {log_dir}\\n\\nLetzte Einträge:\\n{last_logs}"
            dialog = Gtk.MessageDialog(message_format="Smart WiFi Controller")
            dialog.format_secondary_text(info_text)
            dialog.run()
            dialog.destroy()
        except Exception as e:
            print(f"Error: {e}")

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

# Create autostart desktop entry for tray icon
create_tray_icon_autostart() {
    local autostart_dir="$HOME/.config/autostart"
    mkdir -p "$autostart_dir"

    cat > "$autostart_dir/smart-wifi-controller-tray.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Smart WiFi Controller Tray Icon
Comment=Show WiFi Controller status in system tray
Exec=python3 %h/.config/smart_wifi_controller/icons/tray_icon.py
Icon=network-wireless
Terminal=false
Hidden=false
Categories=Network;Utility;
OnlyShowIn=GNOME;KDE;XFCE;Cinnamon;MATE;
StartupNotify=false
EOF
    chmod 644 "$autostart_dir/smart-wifi-controller-tray.desktop"
}

# Start tray icon if available and X11 is available
start_tray_icon_if_available() {
    local tray_script="$TRAY_ICON_DIR/tray_icon.py"

    # Check if tray icon script exists
    if [ ! -f "$tray_script" ]; then
        log_message "WARN" "Tray Icon Script nicht gefunden: $tray_script"
        return 1
    fi

    # Check if Python3 is available
    if ! command -v python3 &> /dev/null; then
        log_message "WARN" "Python3 nicht gefunden - Tray Icon kann nicht gestartet werden"
        return 1
    fi

    # Check if X11 is available
    if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
        log_message "DEBUG" "Keine Desktop-Session erkannt (DISPLAY/WAYLAND nicht gesetzt)"
        return 1
    fi

    # Start tray icon in background
    nohup python3 "$tray_script" > /dev/null 2>&1 &
    local pid=$!
    log_message "INFO" "Tray Icon gestartet (PID: $pid)"
    return 0
}

# Main daemon loop
main() {
    ensure_directories
    create_tray_icon
    create_tray_icon_script
    create_tray_icon_autostart
    save_pid

    log_message "INFO" "======================================"
    log_message "SUCCESS" "Smart WiFi Controller Daemon gestartet (PID: $$)"
    log_message "INFO" "Log-Datei: $LOG_FILE"
    log_message "INFO" "Tray Icon Autostart: $HOME/.config/autostart/smart-wifi-controller-tray.desktop"
    log_message "INFO" "======================================"
    update_status "Initialisierung..."

    # Trap signals for clean shutdown
    trap cleanup SIGTERM SIGINT

    # Try to start tray icon if in desktop session
    start_tray_icon_if_available

    # Main loop - check every 5 seconds
    while true; do
        manage_network > /dev/null 2>&1
        update_daemon_status_display
        sleep 5
    done
}

# Run main function
main
