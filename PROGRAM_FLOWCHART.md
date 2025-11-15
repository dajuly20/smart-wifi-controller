# Smart WiFi Controller - Programmablaufplan

## � Übersicht - Hauptkomponenten

```mermaid
flowchart TD
    START(["🚀 Start"]) --> ARGS{"Parameter?"}
    
    ARGS -->|--help| HELP["📋 Hilfe"]
    ARGS -->|--status| STATUS_CHECK["📊 Status prüfen"]
    ARGS -->|--log| LOG_VIEW["📝 Log anzeigen"] 
    ARGS -->|--manual| MANUAL_RUN["⚙️ Manuell"]
    ARGS -->|GUI| GUI_START["🖥️ GUI starten"]
    
    GUI_START --> NET_CHECK["🔍 Netzwerk prüfen"]
    NET_CHECK --> USER_DIALOG["💬 Benutzer fragen"]
    USER_DIALOG --> ACTION["⚡ Aktion ausführen"]
    ACTION --> LOG_RESULT["📝 Loggen"]
    
    MANUAL_RUN --> NET_CHECK
    STATUS_CHECK --> SHOW_STATUS["� Status zeigen"]
    LOG_VIEW --> SHOW_LOG["📄 Log zeigen"]
    
    HELP --> END_OK(["✅ Ende"])
    SHOW_STATUS --> END_OK
    SHOW_LOG --> END_OK
    LOG_RESULT --> END_OK
    
    style START fill:#e1f5fe
    style END_OK fill:#c8e6c9
    style GUI_START fill:#fff3e0
    style ACTION fill:#ffecb3
```

## 🔌 Netzwerk-Erkennung

```mermaid
flowchart LR
    CHECK_START["🔍 Netzwerk-Check"] --> ETH_STATUS["🔌 Ethernet Status"]
    ETH_STATUS --> WIFI_STATUS["📶 WiFi Status"]
    
    ETH_STATUS --> ETH_CONN{"Ethernet<br/>verbunden?"}
    WIFI_STATUS --> WIFI_ON{"WiFi<br/>aktiv?"}
    
    ETH_CONN -->|Ja| ETH_ACTIVE["✅ Ethernet aktiv"]
    ETH_CONN -->|Nein| ETH_INACTIVE["❌ Ethernet inaktiv"]
    
    WIFI_ON -->|Ja| WIFI_ACTIVE["✅ WiFi aktiv"]
    WIFI_ON -->|Nein| WIFI_INACTIVE["❌ WiFi inaktiv"]
    
    ETH_ACTIVE --> DECISION_MATRIX
    ETH_INACTIVE --> DECISION_MATRIX
    WIFI_ACTIVE --> DECISION_MATRIX
    WIFI_INACTIVE --> DECISION_MATRIX
    
    DECISION_MATRIX["🎯 Entscheidungsmatrix"]
    
    style ETH_ACTIVE fill:#c8e6c9
    style WIFI_ACTIVE fill:#c8e6c9
    style ETH_INACTIVE fill:#ffcdd2
    style WIFI_INACTIVE fill:#ffcdd2
```

## ⚡ Aktions-Matrix

```mermaid
flowchart TD
    MATRIX["🎯 Entscheidungsmatrix"] --> CASE1{"Ethernet: ✅<br/>WiFi: ✅"}
    MATRIX --> CASE2{"Ethernet: ❌<br/>WiFi: ❌"}
    MATRIX --> CASE3{"Ethernet: ✅<br/>WiFi: ❌"}
    MATRIX --> CASE4{"Ethernet: ❌<br/>WiFi: ✅"}
    
    CASE1 -->|Aktion nötig| DISABLE_WIFI["�❌ WiFi deaktivieren"]
    CASE2 -->|Aktion nötig| ENABLE_WIFI["📶✅ WiFi aktivieren"]
    CASE3 -->|OK| NO_ACTION1["ℹ️ Keine Aktion"]
    CASE4 -->|OK| NO_ACTION2["ℹ️ Keine Aktion"]
    
    DISABLE_WIFI --> SUCCESS_DISABLE["✅ WiFi deaktiviert"]
    ENABLE_WIFI --> SUCCESS_ENABLE["✅ WiFi aktiviert"]
    
    SUCCESS_DISABLE --> LOG_SUCCESS["📝 Erfolg loggen"]
    SUCCESS_ENABLE --> LOG_SUCCESS
    NO_ACTION1 --> LOG_INFO["📝 Info loggen"]
    NO_ACTION2 --> LOG_INFO
    
    LOG_SUCCESS --> DONE["🏁 Fertig"]
    LOG_INFO --> DONE
    
    style DISABLE_WIFI fill:#ffecb3
    style ENABLE_WIFI fill:#e8f5e8
    style SUCCESS_DISABLE fill:#c8e6c9
    style SUCCESS_ENABLE fill:#c8e6c9
```

## 🖥️ GUI-Workflow (kompakt)

```mermaid
flowchart TD
    GUI["🖥️ GUI Start"] --> CHECK_DEPS["🔍 Deps prüfen"]
    CHECK_DEPS -->|❌| ERROR_MSG["❌ Fehler zeigen"]
    CHECK_DEPS -->|✅| GET_STATUS["📊 Status holen"]
    
    GET_STATUS --> ANALYZE["🧠 Analysieren"]
    
    ANALYZE --> ACTION_NEEDED{"Aktion<br/>nötig?"}
    ACTION_NEEDED -->|Nein| INFO_DIALOG["ℹ️ Info-Dialog"]
    ACTION_NEEDED -->|Ja| QUESTION_DIALOG["❓ Frage-Dialog"]
    
    QUESTION_DIALOG --> USER_CHOICE{"Benutzer<br/>Wahl"}
    USER_CHOICE -->|Ja| EXECUTE["⚡ Ausführen"]
    USER_CHOICE -->|Nein| CANCELLED["🚫 Abgebrochen"]
    USER_CHOICE -->|Log| SHOW_LOG_GUI["📋 Log zeigen"]
    
    INFO_DIALOG --> OFFER_LOG{"Log zeigen?"}
    OFFER_LOG -->|Ja| SHOW_LOG_GUI
    OFFER_LOG -->|Nein| GUI_END
    
    EXECUTE --> LOG_RESULT_GUI["📝 Loggen"]
    CANCELLED --> GUI_END
    SHOW_LOG_GUI --> GUI_END
    ERROR_MSG --> GUI_END
    LOG_RESULT_GUI --> SUCCESS_MSG["✅ Erfolg zeigen"]
    SUCCESS_MSG --> GUI_END["🏁 GUI Ende"]
    
    style GUI fill:#fff3e0
    style EXECUTE fill:#ffecb3
    style SUCCESS_MSG fill:#c8e6c9
    style ERROR_MSG fill:#ffcdd2
```

## 📝 Log-System

```mermaid
flowchart LR
    LOG_EVENT["📝 Log-Event"] --> LEVEL{"Log-Level"}
    
    LEVEL -->|INFO| INFO_LOG["ℹ️ INFO"]
    LEVEL -->|SUCCESS| SUCCESS_LOG["✅ SUCCESS"] 
    LEVEL -->|WARN| WARN_LOG["⚠️ WARN"]
    LEVEL -->|ERROR| ERROR_LOG["❌ ERROR"]
    
    INFO_LOG --> FILE_WRITE["📄 Datei schreiben"]
    SUCCESS_LOG --> FILE_WRITE
    WARN_LOG --> FILE_WRITE  
    ERROR_LOG --> FILE_WRITE
    
    FILE_WRITE --> ROTATE_CHECK{"Rotation<br/>nötig?"}
    ROTATE_CHECK -->|Ja| ROTATE["🔄 Log rotieren"]
    ROTATE_CHECK -->|Nein| LOG_DONE["✅ Log fertig"]
    ROTATE --> LOG_DONE
    
    LOG_DONE --> GUI_UPDATE["🖥️ GUI Update"]
    
    style INFO_LOG fill:#e3f2fd
    style SUCCESS_LOG fill:#c8e6c9
    style WARN_LOG fill:#fff3e0
    style ERROR_LOG fill:#ffcdd2
```

## 🔧 Kommandozeilen-Modi (Details)

```mermaid
flowchart LR
    CLI["⌨️ CLI Parameter"] --> HELP_MODE["--help"]
    CLI --> STATUS_MODE["--status"] 
    CLI --> LOG_MODE["--log"]
    CLI --> MANUAL_MODE["--manual"]
    
    HELP_MODE --> HELP_OUTPUT["� Hilfe ausgeben"]
    STATUS_MODE --> STATUS_CHECK["� Netzwerk-Status"]
    LOG_MODE --> LOG_DISPLAY["📄 Log anzeigen"]
    MANUAL_MODE --> DIRECT_EXEC["⚡ Direkte Ausführung"]
    
    STATUS_CHECK --> ETH_CHECK_CLI["🔌 Ethernet"]
    STATUS_CHECK --> WIFI_CHECK_CLI["📶 WiFi"]
    ETH_CHECK_CLI --> STATUS_OUTPUT["📱 Status-GUI"]
    WIFI_CHECK_CLI --> STATUS_OUTPUT
    
    LOG_DISPLAY --> LOG_GUI_CHECK{"GUI verfügbar?"}
    LOG_GUI_CHECK -->|Ja| LOG_GUI_SHOW["🖥️ GUI Log"]
    LOG_GUI_CHECK -->|Nein| LOG_CONSOLE["� Konsole Log"]
    
    DIRECT_EXEC --> NETWORK_MGMT["🔄 Management"]
    NETWORK_MGMT --> CLI_RESULT["📝 CLI Ergebnis"]
    
    HELP_OUTPUT --> CLI_END["🏁 Ende"]
    STATUS_OUTPUT --> CLI_END
    LOG_GUI_SHOW --> CLI_END
    LOG_CONSOLE --> CLI_END
    CLI_RESULT --> CLI_END
    
    style HELP_MODE fill:#e3f2fd
    style STATUS_MODE fill:#f3e5f5
    style LOG_MODE fill:#fff3e0  
    style MANUAL_MODE fill:#ffecb3
```

## ⚙️ Systemintegration

```mermaid
flowchart TD
    INSTALL["🔧 Installation"] --> SYS_CHECK["🔍 System prüfen"]
    SYS_CHECK --> DEPS_INSTALL["📦 Abhängigkeiten"]
    
    DEPS_INSTALL --> NMCLI_CHECK{"nmcli<br/>verfügbar?"}
    DEPS_INSTALL --> GUI_CHECK{"GUI-Tools<br/>verfügbar?"}
    
    NMCLI_CHECK -->|Nein| INSTALL_NM["📦 NetworkManager"]
    GUI_CHECK -->|Nein| INSTALL_GUI["📦 Zenity/KDialog"]
    
    INSTALL_NM --> COPY_FILES["📁 Dateien kopieren"]
    INSTALL_GUI --> COPY_FILES
    NMCLI_CHECK -->|Ja| COPY_FILES
    GUI_CHECK -->|Ja| COPY_FILES
    
    COPY_FILES --> CREATE_LINKS["🔗 Links erstellen"]
    CREATE_LINKS --> DESKTOP_ENTRY["🖥️ Desktop-Eintrag"]
    DESKTOP_ENTRY --> INSTALL_COMPLETE["✅ Installation fertig"]
    
    style INSTALL fill:#e1f5fe
    style INSTALL_COMPLETE fill:#c8e6c9
    style INSTALL_NM fill:#fff3e0
    style INSTALL_GUI fill:#fff3e0
```

---
*Erstellt für Smart WiFi Controller v1.0 - November 2025*