# Smart WiFi Controller Script

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
sudo cp smart_wifi_controller.sh /usr/local/bin/smart-wifi-controller
sudo chmod +x /usr/local/bin/smart-wifi-controller

# Abhängigkeiten installieren (Ubuntu/Debian)
sudo apt update && sudo apt install network-manager zenity

# Abhängigkeiten installieren (Fedora/RHEL)
sudo dnf install NetworkManager zenity
```

## Verwendung

### Interaktive GUI (Standard)

```bash
smart-wifi-controller
```

Startet das Script mit grafischer Benutzeroberfläche. Das Script erkennt automatisch den Netzwerkstatus und bietet entsprechende Aktionen an:

- Bei aktiver Ethernet-Verbindung und eingeschaltetem WiFi: Option zum Deaktivieren von WiFi
- Bei inaktiver Ethernet-Verbindung und ausgeschaltetem WiFi: Option zum Aktivieren von WiFi
- Checkbox "Immer automatisch ausführen" für Hintergrund-Automatisierung

### Kommandozeilen-Optionen

```bash
# Aktuellen Netzwerkstatus anzeigen
smart-wifi-controller --status

# Einmalige manuelle Ausführung (ohne GUI)
smart-wifi-controller --manual

# Log-Einträge anzeigen
smart-wifi-controller --log

# Hilfe anzeigen
smart-wifi-controller --help
```

## Automatisierung

**Hinweis**: Die aktuelle Version läuft im "Single-Run-Modus" und bietet keine Hintergrund-Automatisierung. Jede Ausführung überprüft einmalig den Netzwerkstatus und führt bei Bedarf eine Aktion aus.

### Log-Tracking

Das Script protokolliert alle Aktionen in der Datei:
- **Log-Datei**: `~/.local/share/smart_wifi_controller/smart_wifi_controller.log`
- **Konfiguration**: `~/.config/smart_wifi_controller_config`

### Manuelle Wiederholung

```bash
# Einmalige Ausführung
smart-wifi-controller

# Log-Einträge anzeigen
smart-wifi-controller --log
```

## Konfiguration

### Konfigurationsdatei

Speicherort: `~/.config/smart_wifi_controller_config`

```bash
# Smart WiFi Controller Configuration
AUTO_MANAGE="true"
LAST_UPDATE="2024-11-15 14:30:22"
```

### Log-Datei

Speicherort: `~/.local/share/smart_wifi_controller/smart_wifi_controller.log`

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

4. **Log-Dateien überprüfen**
   - Überprüfen Sie: `ls ~/.local/share/smart_wifi_controller/`
   - Log-Inhalt: `smart-wifi-controller --log`

## 📝 Logging-System

### Wo wird geloggt?

**Standard Log-Verzeichnis:**
```bash
~/.local/share/smart_wifi_controller/
├── smart_wifi_controller.log    # Hauptlog-Datei
└── smart_wifi_controller.log.1  # Rotierte Log-Datei (falls vorhanden)
```

**Vollständiger Pfad:**
```bash
# Beispiel für Benutzer "julian"
/home/julian/.local/share/smart_wifi_controller/smart_wifi_controller.log
```

### Log-Level und -Format

Das Script protokolliert verschiedene Ereignisse mit verschiedenen Log-Leveln:

```
[2025-11-15 14:30:15] [INFO] Script gestartet im GUI-Modus
[2025-11-15 14:30:16] [INFO] Ethernet Status: disconnected
[2025-11-15 14:30:16] [INFO] WiFi Status: disabled
[2025-11-15 14:30:17] [SUCCESS] WiFi erfolgreich aktiviert
[2025-11-15 14:30:18] [WARN] Keine Aktion erforderlich
[2025-11-15 14:30:19] [ERROR] NetworkManager nicht verfügbar
```

**Log-Level Erklärung:**
- `INFO`: Allgemeine Informationen über Script-Aktionen
- `SUCCESS`: Erfolgreich durchgeführte Netzwerkänderungen  
- `WARN`: Warnungen oder unerwartete Situationen
- `ERROR`: Fehler bei der Ausführung

### Log-Rotation

- **Maximale Dateigröße:** 1MB pro Log-Datei
- **Anzahl Archive:** 3 rotierte Dateien werden behalten
- **Rotation erfolgt:** Automatisch bei Script-Start wenn Grenze erreicht

### Log-Ausgabe anzeigen

**In der GUI:**
```bash
smart-wifi-controller --log
```

**In der Konsole:**
```bash
# Vollständiges Log anzeigen
cat ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Live-Monitor (folgt neuen Einträgen)
tail -f ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Nur die letzten 20 Zeilen
tail -20 ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Nach Fehlern suchen
grep ERROR ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Nach erfolgreichen Aktionen suchen
grep SUCCESS ~/.local/share/smart_wifi_controller/smart_wifi_controller.log
```

### Log-Inhalte

**Typische Log-Einträge:**

1. **Script-Start:**
   ```
   [2025-11-15 14:30:15] [INFO] Script gestartet im GUI-Modus
   [2025-11-15 14:30:15] [INFO] Zenity GUI verfügbar
   ```

2. **Netzwerk-Checks:**
   ```
   [2025-11-15 14:30:16] [INFO] Ethernet Status: connected (Device: eth0)
   [2025-11-15 14:30:16] [INFO] WiFi Status: enabled (Device: wlan0)
   ```

3. **Benutzer-Aktionen:**
   ```
   [2025-11-15 14:30:17] [INFO] Benutzer hat WiFi-Deaktivierung bestätigt
   [2025-11-15 14:30:17] [SUCCESS] WiFi erfolgreich deaktiviert (Ethernet erkannt)
   ```

4. **Fehler-Protokollierung:**
   ```
   [2025-11-15 14:30:18] [ERROR] Fehler beim Deaktivieren von WiFi: Device not found
   [2025-11-15 14:30:19] [ERROR] nmcli Befehl fehlgeschlagen mit Exit-Code 1
   ```

### Log-Konfiguration

**Standardeinstellungen (nicht änderbar im Single-Run-Modus):**
- **Dateiname:** `smart_wifi_controller.log`
- **Zeitformat:** `YYYY-MM-DD HH:MM:SS`
- **Encoding:** UTF-8
- **Berechtigungen:** 644 (nur Owner kann schreiben)

### Troubleshooting mit Logs

**Häufige Log-Analysen:**

```bash
# Letzte Fehler finden
grep -n ERROR ~/.local/share/smart_wifi_controller/smart_wifi_controller.log | tail -5

# Aktionen der letzten Stunde
grep "$(date +'%Y-%m-%d %H')" ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Alle WiFi-Aktionen anzeigen
grep -E "(aktiviert|deaktiviert)" ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Script-Starts zählen
grep "Script gestartet" ~/.local/share/smart_wifi_controller/smart_wifi_controller.log | wc -l
```

## 📋 Log-Schnellreferenz

| **Befehl** | **Beschreibung** |
|-----------|------------------|
| `smart-wifi-controller --log` | Log in GUI anzeigen |
| `tail -f ~/.local/share/smart_wifi_controller/smart_wifi_controller.log` | Live-Log verfolgen |
| `grep ERROR ~/.local/share/smart_wifi_controller/smart_wifi_controller.log` | Nur Fehler anzeigen |
| `grep SUCCESS ~/.local/share/smart_wifi_controller/smart_wifi_controller.log` | Erfolgreiche Aktionen |
| `tail -20 ~/.local/share/smart_wifi_controller/smart_wifi_controller.log` | Letzte 20 Zeilen |

**Log-Datei Pfad:** `~/.local/share/smart_wifi_controller/smart_wifi_controller.log`

### Debug-Modus

```bash
# Manuellen Modus mit Ausgabe testen
smart-wifi-controller --manual

# Log-Datei überwachen
tail -f ~/.local/share/smart_wifi_controller/smart_wifi_controller.log

# Log-Einträge in GUI anzeigen
smart-wifi-controller --log

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
sudo rm /usr/local/bin/smart-wifi-controller
sudo rm /usr/share/applications/smart-wifi-controller.desktop

# Bei lokaler Installation:
rm ~/.local/bin/smart-wifi-controller
rm ~/.local/share/applications/smart-wifi-controller.desktop

# Konfiguration und Autostart entfernen
rm ~/.config/network_manager_config
rm ~/.config/autostart/network_manager.desktop
```

## Lizenz

Dieses Script steht unter der MIT-Lizenz und kann frei verwendet und modifiziert werden.

## Zukünftige Erweiterungen

### 🔍 **Priorität 1: Intelligente Netzwerk-Erkennung**
- [ ] **Subnet-Erkennung**: Automatische Erkennung ob LAN und WLAN im gleichen Netzwerk/Subnet sind
- [ ] **Sonderfall-Behandlung**: Wenn unterschiedliche Netzwerke erkannt werden → Benutzer fragen oder konfigurierbare Regel anwenden
- [ ] **Bridge-Erkennung**: Erkennung von Netzwerk-Bridges und entsprechende intelligente Behandlung
- [ ] **Gateway-Analyse**: Überprüfung ob beide Verbindungen zum selben Gateway/Router führen
- [ ] **IP-Range-Vergleich**: Vergleich der IP-Adressbereiche von Ethernet und WiFi

### 🌐 **Erweiterte Netzwerk-Features**
- [ ] **Netzwerkprofile**: Profile für verschiedene Umgebungen (Arbeit, Zuhause, öffentlich)
- [ ] **VPN-Integration**: Berücksichtigung von VPN-Verbindungen bei Entscheidungen
- [ ] **Mobile Hotspot**: Management von Smartphone-Hotspots
- [ ] **Zeitbasierte Regeln**: Automatische Umschaltung basierend auf Tageszeit
- [ ] **Bandbreiten-Monitoring**: Bevorzugung der schnelleren Verbindung

### 🔧 **Technische Verbesserungen**
- [ ] **Konfiguration-GUI**: Grafische Konfigurationsoberfläche
- [ ] **System-Tray**: Integration in die Systemleiste
- [ ] **DBus-Integration**: Bessere Desktop-Integration
- [ ] **Mehrere Netzwerk-Interfaces**: Support für mehrere Ethernet/WiFi-Adapter
- [ ] **Notification-System**: Erweiterte Benachrichtigungen über Netzwerkänderungen

### 📦 **Packaging & Distribution**
- [ ] **Debian Package**: .deb-Paket für Ubuntu/Debian
- [ ] **RPM Package**: .rpm-Paket für Fedora/RHEL
- [ ] **AUR Package**: Arch Linux User Repository
- [ ] **Snap Package**: Universelles Snap-Paket
- [ ] **Flatpak**: Flatpak-Distribution

### 💡 **Spezielle Anwendungsfälle**
- [ ] **Enterprise-Mode**: Erweiterte Funktionen für Unternehmen
- [ ] **Roaming-Support**: Intelligente Behandlung bei WiFi-Roaming
- [ ] **Mesh-Netzwerk**: Support für Mesh-WiFi-Systeme
- [ ] **Load-Balancing**: Gleichzeitige Nutzung mehrerer Verbindungen

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