# SchwimmTagebuch

## Überblick
SchwimmTagebuch ist eine SwiftUI-App, die Schwimmtrainings und Wettkämpfe in einer gemeinsamen Datenbank verwaltet. Sie setzt auf SwiftData, stellt die Oberfläche vollständig auf Deutsch dar und bringt ein dreigeteiltes Navigationskonzept aus Kalender, Statistiken und Einstellungen mit.【F:SchwimmTagebuch/App.swift†L4-L53】 Die App registriert beim Start sinnvolle Standardwerte für Trainingsziele, Session-Voreinstellungen sowie Export-Optionen und arbeitet mit einem geteilten SwiftData-Container, der alle relevanten Modelle einschließt.【F:SchwimmTagebuch/App.swift†L6-L41】

## Datenmodell
Alle fachlichen Entitäten sind als `@Model`-Typen umgesetzt und lassen sich damit automatisch im SwiftData-Container speichern.【F:SchwimmTagebuch/Models.swift†L4-L216】 Das zentrale Objekt `TrainingSession` hält Datum, Gesamtumfang, Dauer, Borg-Intensität, Trainingsort, freie Notizen und optionale Stimmung fest und besitzt eine 1:n-Beziehung zu `WorkoutSet`.【F:SchwimmTagebuch/Models.swift†L5-L31】 Die Sets beschreiben Wiederholungen, Distanz, Intervalle, Equipment und Technik-Schwerpunkte; sie enthalten optional Splits (`SetLap`) zur Detailauswertung.【F:SchwimmTagebuch/Models.swift†L55-L168】 Ergänzend lassen sich Wettkämpfe (`Competition`) mit Bahnart und mehreren `RaceResult`-Einträgen dokumentieren, inklusive Disziplin, Distanz, Zeit und PB-Markierung.【F:SchwimmTagebuch/Models.swift†L170-L230】 Enumerationen für Intensität, Ort, Equipment, Technikfoki, Bahnen und Lagen liefern lokalisierte Anzeigenamen und System-SF-Symbole.【F:SchwimmTagebuch/Models.swift†L34-L155】【F:SchwimmTagebuch/Models.swift†L186-L230】

## Hauptfunktionen & Screens
### Kalender
Der Kalender zeigt Trainingseinheiten und Wettkämpfe nach Tagen gruppiert, inklusive Wochenüberblick mit Umfang, Zeit, Borg-Schnitt und Stimmung.【F:SchwimmTagebuch/CalendarViews.swift†L4-L76】 Über das Plus-Menü lassen sich neue Trainings oder Wettkämpfe über modale Editoren anlegen, deren Datum automatisch vorbelegt wird.【F:SchwimmTagebuch/CalendarViews.swift†L84-L133】 Einträge lassen sich aufrufen, bearbeiten und per Swipe entfernen; beim ersten Öffnen eines Datums wird eine leere Session erzeugt, um Lücken zu vermeiden.【F:SchwimmTagebuch/CalendarViews.swift†L89-L162】

### Training & Sets
Im Trainingsdetail werden alle Stammdaten der Session bearbeitet – inklusive Borg-Bewertung, Ort, Gefühl und Notizen – und Sets lassen sich hinzufügen, löschen oder detailliert betrachten.【F:SchwimmTagebuch/SessionViews.swift†L4-L72】 Die Set-Detailansicht erlaubt das Pflegen von Wiederholungen, Distanzen, Intervallen, Kommentaren, Equipment- und Technik-Tags, die auch in der Listenansicht als Badges erscheinen.【F:SchwimmTagebuch/SessionViews.swift†L31-L114】 Für schnelleingaben stehen separate Editor-Sheets zur Verfügung, die Standardwerte aus den Einstellungen übernehmen.【F:SchwimmTagebuch/SessionViews.swift†L192-L272】

### Wettkämpfe
Wettkämpfe erhalten Name, Ort, Bahn und Datum sowie eine Ergebnisliste. Ergebnisse erfassen Disziplin, Distanz, Zeit und Personal-Best-Status und erscheinen direkt in der Liste; ein Stern kennzeichnet PBs.【F:SchwimmTagebuch/CompetitionViews.swift†L4-L82】 Editor-Sheets unterstützen das Anlegen neuer Veranstaltungen oder Resultate mit Stepper-gesteuerten Eingaben und Hundertstelsekunden-Auflösung.【F:SchwimmTagebuch/CompetitionViews.swift†L34-L118】

### Statistiken
Der Statistik-Tab visualisiert Wochenmeter, durchschnittliche Borg-Werte, Equipment- und Technikverteilung sowie einen Wochenziel-Fortschritt über Swift Charts.【F:SchwimmTagebuch/StatsViews.swift†L25-L168】 Aus den Sessions werden Wochen aggregiert, Equipment- und Techniknutzung gezählt und als Balken- bzw. Linien-Diagramme aufbereitet; eine Zusammenfassung der letzten Woche rundet den Überblick ab.【F:SchwimmTagebuch/StatsViews.swift†L30-L159】

### Export & Sicherung
Eine eigene Export-Sektion erzeugt CSV- und JSON-Dateien, bietet einen Schnell-Sync sowie eine optionale automatische Sicherung mit Formatwahl (JSON, CSV oder ZIP-Bundle).【F:SchwimmTagebuch/Export.swift†L4-L102】 Die zugrunde liegende `AutoBackupService`-Logik erstellt Dateien mit Zeitstempel im Dokumentenordner, fasst bei Bedarf mehrere Exporte als ZIP zusammen und verhindert Sicherungen ohne Daten.【F:SchwimmTagebuch/SyncService.swift†L3-L151】 CSV- und JSON-Builder generieren strukturierte Ausgaben, die Equipment- und Technik-Tags verdichten und Sets mit Splits enthalten.【F:SchwimmTagebuch/Export.swift†L111-L185】

### Einstellungen
Der Einstellungsbereich verwaltet Zieltracking (inkl. Wochenziel, optionaler Erinnerungstag), Standardwerte für neue Sessions, Darstellungsoptionen und Sicherungsautomatik. Außerdem können Backups manuell gestartet und alle Daten gelöscht werden.【F:SchwimmTagebuch/SettingsView.swift†L4-L143】 Die Ansicht nutzt `UserDefaults`-gestützte `@AppStorage`-Bindings und öffnet Share-Sheets für erzeugte Sicherungen.【F:SchwimmTagebuch/SettingsView.swift†L13-L124】

## Gestaltung & Hilfsfunktionen
Ein zentrales Material-Extension liefert einen "Liquid Glass"-Look, solange iOS das finale Material nicht bereitstellt.【F:SchwimmTagebuch/Materials.swift†L3-L13】 Utility-Erweiterungen formatieren Zeiten, kapseln optionale Textfelder und verwalten String-Arrays für Equipment/Technik-Toggles.【F:SchwimmTagebuch/Utils.swift†L3-L28】

## Erweiterungspotential
* **Intensitätslogik nutzen:** `TrainingSession` hält bereits ein optionales `Intensitaet`-Feld, das aktuell in der UI nicht angeboten wird. Eine Erweiterung könnte hier eine qualitative Klassifizierung pro Set oder Session ermöglichen.【F:SchwimmTagebuch/Models.swift†L10-L31】
* **Splits erfassen:** Splits (`SetLap`) werden angezeigt, lassen sich aber noch nicht editieren oder importieren. Ein Editor für Zwischenzeiten oder eine Import-Schnittstelle aus Wearables würde das Datenmodell voll ausnutzen.【F:SchwimmTagebuch/SessionViews.swift†L115-L121】【F:SchwimmTagebuch/Models.swift†L157-L168】
* **Erinnerungen hinterlegen:** Die Einstellungen bieten einen Schalter für wöchentliche Erinnerungen, jedoch fehlt die konkrete Anbindung an UserNotifications. Ein Hintergrunddienst könnte Reminder je nach Trainingsziel planen.【F:SchwimmTagebuch/SettingsView.swift†L42-L55】
* **Stimmungsauswertung:** Im Wochenüberblick wird die erste Stimmungstext-Notiz angezeigt; zusätzliche Auswertungen (z. B. Sentiment- oder Wortwolken) könnten das Feature erweitern.【F:SchwimmTagebuch/CalendarViews.swift†L34-L69】
* **Cloud-Sync:** Die Backup-Logik schreibt aktuell in den lokalen Dokumentenordner. Eine Integration in iCloud Drive oder CloudKit würde Mehrgeräte-Szenarien unterstützen.【F:SchwimmTagebuch/SyncService.swift†L13-L60】
* **Visuelles Re-Design:** Das Material-Placeholder weist bereits auf zukünftige Liquid-Glass-Materialien hin; sobald iOS diese bereitstellt, kann das Theme aktualisiert oder durch eigene Shader ergänzt werden.【F:SchwimmTagebuch/Materials.swift†L5-L13】

## Entwicklung & Tests
Das Projekt setzt Swift 5.9, SwiftUI, SwiftData und Charts voraus. In dieser Linux-Umgebung steht keine Xcode-Toolchain zur Verfügung; automatisierte iOS-Tests lassen sich deshalb nur auf einem macOS-System mit Xcode 15 oder neuer ausführen.【F:README.md†L3-L9】 Für plattformunabhängige Tests empfiehlt sich eine zusätzliche Swift-Package-Struktur mit `swift test`-fähigen Modulen.
