# Vliegtuigtas — wat is er nieuw sinds 1.5 (→ 2.0.1)

## Profiel
- Profielpagina volledig herontworpen als geprint bagagelabel: bagagestrook met naam, routing (FROM/TO/FLIGHT/PCS) uit je eerstvolgende vlucht, streepjescode en labelnummer.
- Naam en e-mail zijn nu direct op het profiel te bewerken.
- Boarding-pass-kaart nodigt uit om een review achter te laten in de App Store.
- De automatische review-popup verschijnt nu al na de eerste geslaagde tas-check, en daarna maximaal 1× per 3 maanden per gebruiker.

## Home
- De home-feed is heringedeeld rond één duidelijke missie: eerst checken of je tas past, dan alles om verrassingen bij de gate te voorkomen, en pas daarna tas-suggesties.
- Shop-promotie is rustiger en verplaatst naar onderaan; het "Partneraanbod"-label maakt duidelijk wanneer iets een affiliate-aanbod is.
- Eén rustige accentkleur (navy) voor decoratieve icoontjes door de hele app — kleur betekent nu alleen nog iets bij status (groen/rood/oranje).

## Vluchten
- Vluchtnummer opzoeken haalt nu betrouwbaar de juiste vertrekdatum op (voorheen bleef soms de oude/standaard datum staan).
- Vertrektijd blijft een indicatie zolang de API geen exacte tijd teruggeeft — het scherm is hier nu duidelijk over.

## Winkel / producten
- Nieuwe full-screen productgallerij met knijp/dubbeltik-zoom en swipen tussen foto's.
- Ondersteuning voor meerdere productfoto's per tas, met automatisch doorbladerende hero-carrousel.
- Video op de uitgelichte Amice-koffer.
- Duidelijk onderscheid tussen "kon niet laden" (met opnieuw-knop) en "geen resultaten" in plaats van stilletjes niets tonen.
- Pull-to-refresh in de shop doet nu altijd een echte, verse ophaling bij de server — ook als de catalogus of het luchtvaartmaatschappij-filter al gevuld was.
- Als het verversen van producten of maatschappijen een keer mislukt (bijv. tijdelijk geen verbinding), blijft de al geladen lijst gewoon zichtbaar in plaats van leeg te klappen.

## Luchthavens
- Consistente "Gereed"-knoppen op alle info-sheets (EU-regels, douane, bagage) i.p.v. verwarrende terugpijltjes.
- Rijkere luchthaven-detailpagina: plaatsnaam, link naar de officiële website, maatschappij-chips, openingstijden en bagagekluizen.
- Luchthavenlogo's via logo.dev, met eigen vliegtuig-icoon als fallback.
- Labels consequent in het Nederlands ("Lowcost-hub", "Nog niet in gebruik").

## Herinneringen
- Reistips, checklists en EU-handbagageregels kun je nu opslaan in een eigen "Vliegtuigtas"-lijst in de Herinneringen-app.

## Toegankelijkheid
- De hele checker-flow (maatschappij → afmetingen → resultaat) is nu volledig Dynamic Type-native: tekst schaalt mee met je voorkeurs-tekstgrootte.
- Foto-carrousels bladeren niet meer automatisch door als "Verminder beweging" aanstaat.
- VoiceOver-labels op icoon-only bediening (gewicht, filters, wis-zoekopdracht) en het resultaatscherm wordt als één duidelijke zin voorgelezen.

## Uiterlijk
- Frutiger als nieuw hoofdlettertype door de hele app, widgets en Live Activities (zakelijker en beter leesbaar dan het vorige ronde systeemlettertype). Op de Watch blijft bewust het native lettertype staan.

## Prestaties & techniek
- API-laag zuiniger richting de server: gelijktijdige identieke verzoeken worden gebundeld (request coalescing), en meer endpoints hebben nu een korte cache.
- Diverse build-fixes voor Watch, Widgets, App Clip en Mac Catalyst (o.a. font-registratie, ontbrekende targets, StoreKit-import).

---
*Dit overzicht dekt alle wijzigingen tussen versie 1.5 en 2.0.1.*
