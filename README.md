# Network Manager Script

Ein intelligentes Bash-Script zur automatischen Verwaltung von WiFi- und Ethernet-Verbindungen mit grafischer Benutzeroberfläche.

## Funktionen

- **Automatische Netzwerkverwaltung**: Deaktiviert WiFi automatisch, wenn eine Ethernet-Verbindung aktiv ist
- **GUI-Interface**: Benutzerfreundliche grafische Oberfläche mit Zenity oder KDialog
- **Automatisierungsoption**: "Immer so"-Checkbox für automatische Ausführung im Hintergrund
- **Daemon-Modus**: Kontinuierliche Überwachung der Netzwerkverbindungen
- **Logging**: Detaillierte Protokollierung aller Aktionen
- **Desktop-Integration**: Einfacher Zugriff über das Anwendungsmenü

## Systemanforderungen

- Linux-System mit NetworkManager
- Bash-Shell
- GUI-Toolkit: Zenity (empfohlen) oder KDialog
- Root-Rechte für Netzwerkänderungen

## Installation

### Automatische Installation

```bash
# Repository klonen oder Dateien herunterladen
cd disableWifiOnWiredConnection

# Script ausführbar machen
chmod +x install.sh

# Systemweite Installation (empfohlen):
sudo ./install.sh

# Oder lokale Installation:
./install.sh
```

### Manuelle Installation

```bash
# Script kopieren
sudo cp network_manager.sh /usr/local/bin/network-manager
sudo chmod +x /usr/local/bin/network-manager

# Abhängigkeiten installieren (Ubuntu/Debian)
sudo apt update && sudo apt install network-manager zenity

# Abhängigkeiten installieren (Fedora/RHEL)
sudo dnf install NetworkManager zenity
```

## Verwendung

### Interaktive GUI (Standard)

```bash
network-manager
```

Startet das Script mit grafischer Benutzeroberfläche. Das Script erkennt automatisch den Netzwerkstatus und bietet entsprechende Aktionen an:

- Bei aktiver Ethernet-Verbindung und eingeschaltetem WiFi: Option zum Deaktivieren von WiFi
- Bei inaktiver Ethernet-Verbindung und ausgeschaltetem WiFi: Option zum Aktivieren von WiFi
- Checkbox "Immer automatisch ausführen" für Hintergrund-Automatisierung

### Kommandozeilen-Optionen

```bash
# Aktuellen Netzwerkstatus anzeigen
network-manager --status

# Einmalige manuelle Ausführung (ohne GUI)
network-manager --manual

# Automatisierung aktivieren
network-manager --enable-auto

# Automatisierung deaktivieren
network-manager --disable-auto

# Daemon-Modus (Hintergrundausführung)
network-manager --daemon

# Hilfe anzeigen
network-manager --help
```

## Automatisierung

### Aktivierung

Wenn Sie die Checkbox "Immer automatisch ausführen" aktivieren, passiert folgendes:

1. **Konfiguration wird gespeichert** in `~/.config/network_manager_config`
2. **Autostart-Eintrag wird erstellt** in `~/.config/autostart/network_manager.desktop`
3. **Daemon startet** beim nächsten Login automatisch

### Deaktivierung

```bash
network-manager --disable-auto
```

Oder manuell:
- Autostart-Datei löschen: `~/.config/autostart/network_manager.desktop`
- Konfigurationsdatei bearbeiten: `~/.config/network_manager_config`

## Konfiguration

### Konfigurationsdatei

Speicherort: `~/.config/network_manager_config`

```bash
# Network Manager Configuration
AUTO_MANAGE="true"
LAST_UPDATE="2024-11-15 14:30:22"
```

### Log-Datei

Speicherort: `/tmp/network_manager.log`

Enthält detaillierte Informationen über:
- Erkannte Netzwerkverbindungen
- Durchgeführte Aktionen
- Fehlermeldungen
- Zeitstempel

## Funktionsweise

### Erkennung von Netzwerkverbindungen

Das Script verwendet NetworkManager (`nmcli`) zur Erkennung von:

- **Ethernet-Verbindungen**: Überprüfung aktiver Ethernet-Connections
- **WiFi-Status**: Abfrage des WiFi-Radio-Status (enabled/disabled)

### Logik

```
Wenn Ethernet verbunden UND WiFi aktiviert:
    → WiFi deaktivieren

Wenn Ethernet getrennt UND WiFi deaktiviert:
    → WiFi aktivieren

Sonst:
    → Keine Aktion erforderlich
```

### Daemon-Modus

- Überprüfung alle 5 Sekunden
- Läuft kontinuierlich im Hintergrund
- Greift nur ein, wenn Automatisierung aktiviert ist

## Problembehandlung

### Häufige Probleme

1. **"nmcli command not found"**
   ```bash
   # Ubuntu/Debian
   sudo apt install network-manager
   
   # Fedora/RHEL
   sudo dnf install NetworkManager
   ```

2. **Keine GUI verfügbar**
   ```bash
   # Zenity installieren
   sudo apt install zenity
   # oder
   sudo dnf install zenity
   ```

3. **Keine Berechtigung für Netzwerkänderungen**
   - Stellen Sie sicher, dass Ihr Benutzer in der Gruppe `netdev` oder `network` ist
   - Oder führen Sie das Script mit `sudo` aus

4. **Autostart funktioniert nicht**
   - Überprüfen Sie: `ls ~/.config/autostart/network_manager.desktop`
   - Desktop-Umgebung unterstützt möglicherweise keine Autostart-Einträge

### Debug-Modus

```bash
# Manuellen Modus mit Ausgabe testen
network-manager --manual

# Log-Datei überwachen
tail -f /tmp/network_manager.log

# Netzwerkstatus direkt überprüfen
nmcli connection show --active
nmcli radio wifi
```

## Sicherheitshinweise

- Das Script benötigt Berechtigung zur Netzwerkverwaltung
- Automatisierung läuft im Benutzerkontext
- Keine sensiblen Daten werden gespeichert
- Log-Dateien enthalten keine Passwörter oder Verbindungsdetails

## Kompatibilität

### Getestete Distributionen

- Ubuntu 20.04+
- Debian 11+
- Fedora 35+
- openSUSE Tumbleweed
- Arch Linux

### Desktop-Umgebungen

- GNOME (mit Zenity)
- KDE Plasma (mit KDialog)
- XFCE (mit Zenity)
- MATE (mit Zenity)

## Deinstallation

```bash
# Systemweite Installation
sudo rm /usr/local/bin/network-manager
sudo rm /usr/share/applications/network-manager.desktop

# Lokale Installation
rm ~/.local/bin/network-manager
rm ~/.local/share/applications/network-manager.desktop

# Konfiguration und Autostart entfernen
rm ~/.config/network_manager_config
rm ~/.config/autostart/network_manager.desktop
```

## Lizenz

Dieses Script steht unter der MIT-Lizenz und kann frei verwendet und modifiziert werden.

## Support

Bei Problemen oder Fragen:

1. Überprüfen Sie die Systemanforderungen
2. Konsultieren Sie die Problembehandlung
3. Erstellen Sie ein Issue mit:
   - Betriebssystem und Version
   - Fehlermeldung oder unerwartetes Verhalten
   - Inhalt der Log-Datei (`/tmp/network_manager.log`)

---

**Version**: 1.0  
**Letzte Aktualisierung**: November 2024