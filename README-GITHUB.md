# Smart WiFi Controller

## 🚀 Intelligente WiFi/Ethernet Verwaltung für Linux

Ein intelligentes Bash-Script mit GUI, das automatisch WiFi deaktiviert wenn Ethernet verfügbar ist, und WiFi aktiviert wenn keine Ethernet-Verbindung besteht.

![Smart WiFi Controller](https://img.shields.io/badge/Platform-Linux-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Bash](https://img.shields.io/badge/Shell-Bash-lightgrey.svg)

## ✨ Features

- 🖥️ **Intuitive GUI** mit Zenity/KDialog Support
- 📊 **Detaillierte Netzwerk-Informationen** (IP-Adressen, Geschwindigkeiten)
- 💾 **"Entscheidung merken bis Neustart"** Feature
- 📝 **Umfassendes Logging** mit GUI-Integration
- ⚡ **Single-Run Modus** - keine Daemon-Prozesse
- 🔧 **Automatische Abhängigkeits-Installation**
- 🎯 **Cross-Desktop kompatibel** (GNOME, KDE, XFCE, etc.)

## 🏃‍♂️ Schnellstart

```bash
# Repository klonen
git clone https://github.com/dajuly20/smart-wifi-controller.git
cd smart-wifi-controller

# Abhängigkeiten installieren und einrichten
./init.sh

# Script testen
./smart_wifi_controller.sh --status

# GUI starten
./smart_wifi_controller.sh

# Installieren (optional)
./install.sh
```

## 📊 Connection Speed Features

Das Script zeigt detaillierte Netzwerk-Informationen:

**Ethernet:**
- Link-Geschwindigkeit (z.B. 1000Mbps)
- Duplex-Modus (Full/Half)
- IP-Adresse und Subnet
- Link-Status

**WiFi:**
- Upload/Download-Geschwindigkeit (↑150Mbps / ↓300Mbps)
- Signalstärke (-45 dBm)
- Frequenz (2.4/5GHz)
- SSID des Netzwerks

## 🖥️ Verwendung

```bash
./smart_wifi_controller.sh                  # GUI-Modus
./smart_wifi_controller.sh --status         # Netzwerk-Status anzeigen
./smart_wifi_controller.sh --log            # Log-Einträge anzeigen
./smart_wifi_controller.sh --manual         # Einmalige Ausführung
./smart_wifi_controller.sh --clear-decision # Gespeicherte Entscheidung löschen
./smart_wifi_controller.sh --help           # Hilfe anzeigen
```

## 📁 Projektstruktur

```
smart-wifi-controller/
├── smart_wifi_controller.sh    # Hauptscript
├── install.sh                  # Installation
├── init.sh                     # Projekt-Setup
├── test.sh                     # Test-Suite
├── README.md                   # Diese Datei
├── PROGRAM_FLOWCHART.md         # Mermaid-Diagramme
├── PROJECT_OVERVIEW.md          # Projekt-Übersicht
└── docs/                       # Dokumentation
    ├── PSEUDOCODE_README.md
    └── examples/
```

## 🔧 Systemanforderungen

- **Linux Distribution** (Ubuntu, Debian, Fedora, openSUSE, Arch)
- **NetworkManager** (`nmcli` command)
- **GUI Toolkit**: Zenity (GNOME) oder KDialog (KDE)
- **Bash** 4.0+

## 🏗️ Installation

### Automatische Installation

```bash
./init.sh        # Abhängigkeiten prüfen und installieren
./install.sh     # Script systemweit installieren
```

### Manuelle Installation

```bash
# Abhängigkeiten installieren
sudo apt update && sudo apt install network-manager zenity  # Ubuntu/Debian
sudo dnf install NetworkManager zenity                      # Fedora
sudo zypper install NetworkManager zenity                   # openSUSE
sudo pacman -S networkmanager zenity                        # Arch

# Script ausführbar machen
chmod +x smart_wifi_controller.sh
```

## 📝 Logging

Alle Aktionen werden protokolliert in:
```
~/.local/share/smart_wifi_controller/smart_wifi_controller.log
```

**Log-Level:**
- `INFO`: Allgemeine Informationen
- `SUCCESS`: Erfolgreiche Netzwerkänderungen
- `WARN`: Warnungen
- `ERROR`: Fehler

## 🤝 Beitragen

1. Fork das Repository
2. Feature Branch erstellen (`git checkout -b feature/AmazingFeature`)
3. Changes committen (`git commit -m 'Add AmazingFeature'`)
4. Branch pushen (`git push origin feature/AmazingFeature`)
5. Pull Request öffnen

## 📄 Lizenz

Dieses Projekt steht unter der MIT License. Siehe `LICENSE` Datei für Details.

## 🙏 Danksagungen

- NetworkManager Team für das ausgezeichnete CLI-Tool
- Zenity/KDialog Entwickler für die GUI-Frameworks
- Linux Community für die kontinuierliche Inspiration

## 📞 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/dajuly20/smart-wifi-controller/issues)
- 💬 **Diskussionen**: [GitHub Discussions](https://github.com/dajuly20/smart-wifi-controller/discussions)
- 📧 **Email**: Siehe GitHub Profil

---
**Entwickelt mit ❤️ für die Linux Community**