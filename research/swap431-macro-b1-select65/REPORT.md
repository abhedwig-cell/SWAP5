# SWAP431-MACRO-B1-SELECT65

## Resultaat

Geen echte stapafwijzing met actieve V-aanvulling gevonden in acht gericht gekozen voorstellen uit het resterende oorspronkelijke D2-interval van REJECT64. De selectie stopt bij de vooraf vastgelegde grens. Dit is een negatief selectieresultaat, geen bewijs dat zulke afwijzingen onmogelijk zijn.

Zeven O0-voorstellen accepteren met elk twee geldige V-toepassingen. SELECT5 wijst echt af na 30 iteraties, maar gebruikt uitsluitend W (25 toepassingen, vijf bewaakte terugvallen). De automatische retry op dtmin accepteert in drie iteraties met W/V/V. V-activiteit in die retry kwalificeert de voorafgaande afwijzing niet.

De oorspronkelijke bovengrens is eenmaal als referentie herhaald: oorspronkelijke W-afwijzing en kleinere retry reproduceren COMBINED63 exact voor de gecontroleerde fysieke toestand, ledger, correctietrace, inventaris en native vervolgpacket. SELECT4 en SELECT8 zijn met O2 bevestigd: fysieke teksttraces en native vervolgpacket zijn bytegelijk aan O0; alleen rekentijden verschillen.

## Grenzen en bewijs

Elf normale, ongecensureerde routes; maximaal 1.755 seconden per route, onder de twintigsecondenlimiet. Geen compilatie of numerieke bronwijziging: verzegelde REJECT64 O0/O2-binaries en oorspronkelijke NATIVE55-packet. Geen wijziging van fysica, klok, criteria, MAXIT, budgetregels, dtmin, reductie of geldigheidsbewaking. Alle voorstellen blijven in hetzelfde oorspronkelijke D2-startcheckpoint.

De eerste vier middelpunten zijn gevolgd door één O0-identiteitscontrole van de bestaande bovengrens. Daarna zijn vooraf maximaal vier verdere middelpunten vastgelegd in het inmiddels zestienmaal kleinere interval. De volledige chronologie staat in CONTRACT.md en de Git-checkpoints. Er is geen brede contextcampagne gestart.

Bij SELECT5 herstelt de fysieke toestand vóór retry exact, afgezien van de bedoelde controllerwaarden dt en fldtmin; de ledger herstelt bytegelijk. Dit kwalificeert uitsluitend de W-afwijzing. Een onafhankelijke directe kleinere retry voor een V-afwijzing is niet gestart omdat het noodzakelijke echte V-afwijzingspunt ontbreekt. De V-rollback/direct-retry-gate blijft open; geen promotie van de B1-kandidaat.

Resterend niet onderzochte interval: [2.0903186152189966e-5, 2.0908533472519632e-5]. Dit is geen bewezen monotone grens. Niet verder verfijnen binnen deze werkunit.

## Reproductie en herstel

`python -B research/swap431-macro-b1-select65/assess_select65.py` controleert opgeslagen bewijzen zonder modellen te starten. RESULT.json en SELECTION_AUDIT.csv bevatten alle pogingen, iteraties, W/V-activiteit, residuen, rekentijden en inventarisgrenzen. SELECTION_PROGRESS.json bewaart de selectievolgorde. Fysieke beginstaat en ledger zijn tegen COMBINED63 gecontroleerd; alle geaccepteerde stappen hebben een verse residucheck, FrReduQ=1 en IDecMpRat=0 en voldoen aan de bestaande waterinventarisgrens.

SELECT65_EVIDENCE.zip bewaart de volledige cases, ruwe traces en uitvoerbare buildsluiting met per-lid SHA-256-controle. EVIDENCE.json registreert de archiefidentiteit en de geërfde REJECT64-identiteit. Werkpaden in RESOURCE_PATHS.json kunnen na geverifieerde centrale bewaring worden opgeruimd; het archief is de herstelbron.
