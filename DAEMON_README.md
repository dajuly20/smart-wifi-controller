# Smart WiFi Controller - Daemon Betrieb

Der Smart WiFi Controller läuft jetzt als Daemon im Hintergrund und überwacht kontinuierlich die WiFi- und Ethernet-Verbindungen.

## Features

✅ **Automatischer Daemon-Betrieb** - Läuft als Systemd Service
✅ **System Tray Icon** - Zeigt den Status in der Taskleiste
✅ **Automatischer Start** - Startet beim Hochfahren automatisch
✅ **Echtzeit-Überwachung** - Prüft alle 5 Sekunden die Netzwerkverbindungen
✅ **Automatische WiFi-Verwaltung** - Deaktiviert WiFi wenn Ethernet verbunden ist
✅ **Detailliertes Logging** - Alle Änderungen werden geloggt

## Daemon-Befehle

### Daemon starten
```bash
systemctl --user start smart-wifi-controller
```

### Daemon stoppen
```bash
systemctl --user stop smart-wifi-controller
```

### Daemon Status überprüfen
```bash
systemctl --user status smart-wifi-controller
```

### Daemon beim Hochfahren aktivieren
```bash
systemctl --user enable smart-wifi-controller
```

### Daemon beim Hochfahren deaktivieren
```bash
systemctl --user disable smart-wifi-controller
```

### Daemon-Logs anzeigen
```bash
journalctl --user -u smart-wifi-controller -f
```

Oder direkt aus der Datei:
```bash
tail -f ~/.local/share/smart_wifi_controller/daemon.log
```

## System Tray Icon

Das System Tray Icon zeigt:
- **Status des Daemons** - Läuft/nicht aktiv
- **Netzwerk-Status** - WiFi und Ethernet Status
- **Log-Viewer** - Letzte Einträge anzeigen
- **Daemon-Control** - Start/Stop-Buttons

Das Icon startet automatisch beim Hochfahren.

## Automatische Funktionsweise

Der Daemon überprüft ständig:

1. **Ist Ethernet verbunden?**
   - Ja → WiFi wird **deaktiviert**
   - Nein → WiFi wird **aktiviert** (wenn nicht bereits aktiv)

2. **Status wird geloggt**
   - Jede Änderung wird ins Log geschrieben
   - Im System Tray Icon sichtbar

## Verzeichnisse

```
~/.config/smart_wifi_controller/        # Konfiguration & Icons
~/.local/bin/smart_wifi_daemon          # Daemon-Script
~/.local/share/smart_wifi_controller/   # Logs
~/.config/systemd/user/                 # Systemd Service
~/.config/autostart/                    # Autostart-Dateien
```

## Troubleshooting

### Daemon startet nicht
```bash
# Logs überprüfen
journalctl --user -u smart-wifi-controller -n 20

# Service-Status
systemctl --user status smart-wifi-controller
```

### System Tray Icon funktioniert nicht

**Installiere die AppIndicator3 Dependencies:**
```bash
sudo apt update
sudo apt install -y libappindicator3-1 gir1.2-appindicator3-0.1 python3-gi gir1.2-gtk-3.0
```

Für andere Distributionen:
- **Fedora/RHEL:** `sudo dnf install -y libappindicator-gtk3 python3-gobject`
- **Arch:** `sudo pacman -S --needed libappindicator-gtk3 python-gobject`
- **openSUSE:** `sudo zypper install -y libappindicator1 python3-gobject`

Nach der Installation starte den Daemon neu:
```bash
systemctl --user restart smart-wifi-controller
```

Oder starte das Icon manuell:
```bash
python3 ~/.config/smart_wifi_controller/icons/tray_icon.py
```

### Daemon "lädt" ständig neu
Das ist normal - der Daemon prüft alle 5 Sekunden die Verbindungen. Die Logs sollten entsprechende Einträge zeigen.

## Performance

- **CPU-Nutzung:** Minimal (nur alle 5 Sekunden aktiv)
- **RAM-Nutzung:** ~750 KB
- **Netzwerk-Nutzung:** Keine (nur lokale Überprüfung)

## Sicherheit

Der Daemon:
- ✅ Benötigt keine Root-Rechte
- ✅ Läuft als normaler Benutzer
- ✅ Verwendet nur lokale Befehle (nmcli)
- ✅ Schreibt nur in Home-Verzeichnis
