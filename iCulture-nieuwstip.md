# Nieuwstip voor iCulture — Vliegtuigtas: Handbagage Check

> Kant-en-klare tekst om via het iCulture-nieuwstipformulier (of per e-mail) te versturen.
> Vul bij het formulier in: **Naam app**: Vliegtuigtas: Handbagage Check · **iTunes-link**: https://apps.apple.com/app/id6785971912

---

## Onderwerp (voor het "Opmerkingen"-veld of de e-mailtitel)

**Een Nederlandse travel-app die zowat élke Apple-techniek gebruikt — van Live Activities en Apple Watch tot een reisassistent op Apple's on-device Foundation Models**

---

## De tip

Beste redactie,

Even een persoonlijke aanloop, want dit is voor mij een klein cirkeltje-rond-momentje. Ik lees iCulture sinds ik op de middelbare school mijn eerste échte Apple-device kreeg: een iPad, in 2013. Sindsdien wilde ik álles weten over iOS. Ik was ook degene die tegen beter weten in meteen naar iOS 7 updatete — met als gevolg dat de schoolapps er nog totaal niet klaar voor waren en ik dat op mijn eigen houtje mocht uitleggen. Dat "ik-wil-het-nieuwste-nú"-gevoel is nooit weggegaan, en het is uiteindelijk uitgemond in een eigen app.

Die app is **Vliegtuigtas: Handbagage Check**, en ik tip jullie erover omdat het misschien wel dé leukste reis-app is voor Apple-gebruikers die met vertrouwen willen vliegen — juist omdat er zo ongeveer élke Apple-technologie in verwerkt zit, op zowat élk Apple-device.

**In één zin:** meet met de camera (LiDAR/AR) of je handbagage bij jouw maatschappij past, met een database van 69+ luchtvaartmaatschappijen en 127 tariefvarianten — en de rest van je reis (aftellen tot vertrek, inpaktips, regels, luchthaveninfo) leeft mee op je widget, Dynamic Island, Apple Watch, CarPlay en zelfs in de Apple Vision Pro.

### Waarom dit interessant is voor iCulture-lezers

Waar de meeste apps één of twee Apple-features netjes implementeren, is Vliegtuigtas bijna een etalage van wat er in 2026 mogelijk is op het platform. Voor een publiek dat juist geniet van goed geïntegreerde Apple-techniek is dat het verhaal:

- **Apple Intelligence, lokaal.** De ingebouwde reisassistent "Purser Pim" draait op Apple's **Foundation Models** (`SystemLanguageModel` / `LanguageModelSession`) — dus on-device, privacyvriendelijk en zonder server. Bewust géén sparkles of "AI"-labels: Pim is gewoon een behulpzame purser met een pet.
- **Meet je koffer met de camera.** Een **ARKit + LiDAR**-scanner projecteert de toegestane maximale handbagagemaat als een kooi in de ruimte, zodat je letterlijk ziet of je tas past.
- **Overal aanwezig.** Native apps/doelen voor **iPhone, iPad, Apple Watch, Apple Vision Pro**, een **App Clip**, **CarPlay**, en een **Safari-extensie** die tijdens het online shoppen checkt of een koffer als handbagage past.
- **Leeft op je beginscherm.** **Widgets** (WidgetKit), **Live Activities & Dynamic Island** (ActivityKit) met een aftelling tot vertrek, plus **AlarmKit**-alarmen voor "controleren, inpakken, afgeven".
- **Volledig in het systeem verweven.** **App Intents & Siri Shortcuts**, **Spotlight**-indexering van maatschappijen, **iCloud**-synchronisatie tussen al je apparaten, verwisselbare **app-iconen**, en sinds kort een **Herinneringen (EventKit)**-integratie om reistips en checklists op te slaan in een eigen "Vliegtuigtas"-lijst.
- **iOS 26-look.** De zwevende Liquid Glass-tabbalk, haptische microfeedback overal, en vloeiende animaties — gebouwd met het nieuwste SwiftUI.

### Wat de app doet (de kern)

1. **Kies je maatschappij** (of zoek op vluchtnummer) en **meet je tas** — met de sliders of met de AR-camera.
2. Je krijgt direct een **oordeel**: past hij als handbagage, als klein persoonlijk item, of niet? Inclusief wielmarge en gewicht.
3. Past-ie niet? Dan zie je meteen **koffers en tassen die wél passen** bij jouw maatschappij.
4. Nieuw in deze versie: een complete **luchthavensectie** voor alle Nederlandse vliegvelden (Schiphol, Eindhoven, Rotterdam The Hague, Groningen Eelde, Maastricht en het nog-niet-open Lelystad), met security-eigenaardigheden per luchthaven (welke hebben 3D CT-scanners?), **EU-handbagageregels**, **douane-informatie** en een **"bagage kwijt of beschadigd"-hulpsectie** met de PIR-procedure.

Handig detail voor een reisverhaal: op **Eindhoven Airport** kost een verkeerd ingeschatte tas aan de gate zomaar €60–70 — de app is er letterlijk op gebouwd om die verrassing te voorkomen.

### Praktische informatie

- **Naam:** Vliegtuigtas: Handbagage Check
- **App Store:** https://apps.apple.com/app/id6785971912 (Apple ID 6785971912)
- **Prijs:** gratis
- **Platforms:** iPhone, iPad, Apple Watch, Apple Vision Pro, CarPlay, App Clip + Safari-extensie
- **Nieuwste versie:** 1.5
- **Werkt offline:** de catalogus wordt lokaal gecachet, dus checken kan ook zonder verbinding
- **Taal:** Nederlands
- **Maker:** Wouter Schut (onafhankelijke ontwikkelaar)
- **Contact:** wouterschut1@gmail.com

### Mogelijke invalshoeken voor een artikel

- *"Deze Nederlandse app gebruikt zowat élke Apple-feature — en is nog gratis ook"*
- *"Apple Intelligence in de praktijk: een reisassistent die volledig on-device draait"*
- *"Meet met je iPhone (LiDAR) of je handbagage past — en voorkom de €70-boete op Eindhoven"*
- *"Van iPhone tot Vision Pro: één reis-app op al je Apple-apparaten"*

Ik lever met alle plezier extra screenshots, een preview-build (TestFlight), of beeldmateriaal van de AR-scanner en de Live Activity aan — laat maar weten wat handig is. En mocht het niks voor jullie zijn: dan nog bedankt dat iCulture er al ruim tien jaar is. Zonder die dagelijkse dosis Apple-nieuws was deze app er waarschijnlijk nooit gekomen.

Hartelijke groet,
Wouter

---

## Bijlage: volledige lijst van gebruikte Apple-frameworks & technologieën

*(Voor de redactie — puur ter onderbouwing; niet bedoeld voor publicatie.)*

| Technologie | Framework | Waar in de app |
|---|---|---|
| On-device AI-assistent "Purser Pim" | FoundationModels (`SystemLanguageModel`, `LanguageModelSession`) | Reisvragen beantwoorden, tips |
| AR-koffermeting met LiDAR | ARKit + SceneKit | "Scan je tas met de camera" |
| Live Activities & Dynamic Island | ActivityKit | Aftelling tot vertrek |
| Home- & lockscreen-widgets | WidgetKit | Vlucht- en checker-widgets |
| Inpak-/vertrekalarmen | AlarmKit | "Controleren, inpakken, afgeven" |
| Siri Shortcuts & App Intents | AppIntents | Bagageregels/vlucht opvragen, vlucht toevoegen |
| Spotlight-indexering | CoreSpotlight | Maatschappijen doorzoekbaar |
| Herinneringen opslaan | EventKit | Reistips & checklists → eigen lijst |
| Synchronisatie tussen apparaten | iCloud / CloudKit | Vluchten, tasmaten, voorkeuren |
| Auto/onderweg | CarPlay | CarPlay-scene |
| Handbagage checken tijdens shoppen | Safari Web Extension | Aparte extensie-target |
| Haptische feedback | CoreHaptics / UIKit haptics | Door de hele app |
| Notificaties | UserNotifications | Vertrekreminders |
| visionOS | SwiftUI (Vision-target) | Apple Vision Pro-versie |
| watchOS | SwiftUI + App Intents (Watch-target) | Apple Watch-app + complicaties |
| App Clip | App Clip-target | Snel checken zonder installeren |
| Verwisselbare app-iconen | Alternate App Icons | Standaard / Pim / Flap |
| iOS 26 Liquid Glass | SwiftUI (`glassEffect`, `tabBarMinimizeBehavior`) | Zwevende tabbalk & chrome |
