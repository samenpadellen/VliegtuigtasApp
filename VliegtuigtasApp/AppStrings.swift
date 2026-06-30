import Foundation

/// All user-facing strings in Dutch and English.
/// Access via `session.strings` — views re-render automatically when `session.language` changes.
struct AppStrings {
    let language: String
    private var en: Bool { language == "en" }

    // MARK: - Common
    var done: String    { en ? "Done"   : "Klaar" }
    var back: String    { en ? "Back"   : "Terug" }
    var next: String    { en ? "Next"   : "Volgende" }
    var cancel: String  { en ? "Cancel" : "Annuleer" }
    var search: String  { en ? "Search" : "Zoek" }

    // MARK: - Home
    var heroTitle: String       { en ? "Does your bag\nfit on the plane?"          : "Past jouw tas\nin het vliegtuig?" }
    var heroSubtitle: String    { en ? "Check the rules of Ryanair, KLM,\neasyJet and more instantly." : "Check direct de regels van Ryanair,\nKLM, easyJet en meer." }
    var checkButton: String     { en ? "Check my cabin bag"                        : "Controleer mijn handbagage" }
    var flightLookupTitle: String { en ? "Look up flight number"                   : "Vluchtnummer opzoeken" }
    var flightLookupHint: String  { en ? "e.g. KL1234 or FR7542"                  : "bijv. KL1234 of FR7542" }
    var searchLabel: String     { en ? "Search"                                    : "Zoek" }
    var popularAirlines: String { en ? "Popular airlines"                          : "Populaire maatschappijen" }
    var viewAll: String         { en ? "View all"                                  : "Bekijk alle" }
    var howItWorksTitle: String { en ? "How does it work?"                         : "Hoe werkt het?" }
    var step1Title: String      { en ? "Choose your airline"                       : "Kies je maatschappij" }
    var step1Sub: String        { en ? "Or search automatically via flight number.": "Of zoek automatisch via vluchtnummer." }
    var step2Title: String      { en ? "Enter your bag dimensions"                 : "Vul je tasmaten in" }
    var step2Sub: String        { en ? "Length, width, depth and weight."          : "Lengte, breedte, hoogte en gewicht." }
    var step3Title: String      { en ? "Instant result"                            : "Direct resultaat" }
    var step3Sub: String        { en ? "Doesn't fit? We recommend the right bag." : "Past het niet? We adviseren de juiste tas." }

    // MARK: - Accessibility
    var accessibilityTitle: String    { en ? "Accessibility"                              : "Toegankelijkheid" }
    var accessibilitySub: String      { en ? "Adjust the app to suit your needs."         : "Pas de app aan op jouw behoeften." }
    var largeTextTitle: String        { en ? "Larger text"                                : "Grotere tekst" }
    var largeTextSub: String          { en ? "Increases text size throughout the app."    : "Vergroot tekst door de hele app." }
    var highContrastTitle: String     { en ? "High contrast"                              : "Hoog contrast" }
    var highContrastSub: String       { en ? "Stronger colours for better readability."   : "Sterkere kleuren voor betere leesbaarheid." }
    var reduceMotionTitle: String     { en ? "Reduce motion"                              : "Minder animaties" }
    var reduceMotionSub: String       { en ? "Reduces animations and transitions."        : "Vermindert animaties in de app." }
    var redoOnboarding: String        { en ? "View introduction again"                    : "Introductie opnieuw bekijken" }

    // MARK: - Onboarding – Welcome
    var welcomeTitle: String          { en ? "Never surprised\nat the gate."              : "Nooit meer\nverrast bij de gate." }
    var welcomeSub: String            { en ? "Check in seconds if your cabin bag meets the rules of Ryanair, KLM, easyJet and more." : "Controleer in seconden of jouw handbagage past bij Ryanair, KLM, easyJet en meer." }
    var feature1: String              { en ? "Know instantly if your bag fits"            : "Direct weten of jouw tas past" }
    var feature2: String              { en ? "Bags recommended that always fit"           : "Tassen aanbevolen die altijd passen" }
    var feature3: String              { en ? "All major European airlines"                : "Alle grote Europese maatschappijen" }
    var getStarted: String            { en ? "Get started"                                : "Aan de slag" }

    // MARK: - Onboarding – Name
    var nameTitle: String             { en ? "Nice to\nmeet you"                          : "✋ Even\nvoorstellen" }
    var nameQ: String                 { en ? "What should we call you?"                   : "Hoe mogen we je noemen?" }
    var nameQSub: String              { en ? "So we can help you personally."             : "Zodat we je persoonlijk kunnen helpen." }
    var firstNameLabel: String        { en ? "First name"                                 : "Voornaam" }
    var firstNamePlaceholder: String  { en ? "e.g. Emma or Luca"                         : "bijv. Emma of Luca" }
    var firstNameError: String        { en ? "Please enter your first name"               : "Vul je voornaam in" }

    // MARK: - Onboarding – Email
    var emailTitle: String            { en ? "What's your\nemail?"                        : "Wat is je\ne-mailadres?" }
    var emailSub: String              { en ? "We'll send you travel tips and alerts when rules change." : "We sturen je handige reistips en alerts als regels veranderen." }
    var emailLabel: String            { en ? "Email address"                              : "E-mailadres" }
    var emailPlaceholder: String      { en ? "your@email.com"                             : "jouw@email.nl" }
    var emailError: String            { en ? "Please enter a valid email address"         : "Vul een geldig e-mailadres in" }
    var nextStep: String              { en ? "Next"                                       : "Volgende" }
    var privacyNote: String           { en ? "We never share your data with third parties." : "We delen je gegevens nooit met derden." }

    // MARK: - Onboarding – Accessibility page
    var accessPageTitle: String       { en ? "Make it yours"                              : "Maak het jouw app" }
    var accessPageSub: String         { en ? "Set up accessibility to make the app as comfortable as possible." : "Stel toegankelijkheid in voor maximaal gebruiksgemak." }
    var finishButton: String          { en ? "Finish setup"                               : "Afronden" }
    var skipButton: String            { en ? "Skip"                                       : "Overslaan" }

    // MARK: - Checker
    var chooseAirline: String         { en ? "Which airline\nare you flying with?"        : "Met welke\nmaatschappij vlieg je?" }
    var chooseAirlineSub: String      { en ? "Choose your airline."                       : "Kies je luchtvaartmaatschappij." }
    var searchAirline: String         { en ? "Search airline"                             : "Zoek maatschappij" }
    var howBig: String                { en ? "How big is\nyour cabin bag?"                : "Hoe groot is\njouw handbagage?" }
    var measureTip: String            { en ? "Measure your bag and fill in the dimensions." : "Meet jouw tas op en vul de maten in." }
    var heightLabel: String           { en ? "Height"                                     : "Hoogte" }
    var widthLabel: String            { en ? "Width"                                      : "Breedte" }
    var depthLabel: String            { en ? "Depth"                                      : "Diepte" }
    var weightLabel: String           { en ? "Weight"                                     : "Gewicht" }
    var kilogram: String              { en ? "kilogram"                                   : "kilogram" }
    var checkNow: String              { en ? "Check now"                                  : "Controleer nu" }
    var checking: String              { en ? "Checking…"                                  : "Controleren…" }
    var checkAgain: String            { en ? "Check again"                                : "Opnieuw controleren" }
    var disclaimer: String            { en ? "This is an estimate. Always check the official rules of the airline." : "Dit is een indicatie. Controleer altijd de officiële regels van de maatschappij." }
}
