# CLOCK45: doorlopen sorptieklok bij dezelfde90 nul-eindoverlap-events

**De klok loopt bij deze90 events terecht door binnen het huidige contactmodel.** De cel verliest niet al haar macroporiewatercontact en in alle90 geaccepteerde stappen blijft werkelijke sorptie over na de voorraadbegrenzing. Nul onverzadigde overlap in de eindgeometrie is hier geen volledige contactbreuk. O0 en O2 bevestigen dit numeriek identiek. Er is geen klok- of fysicacorrectie uitgevoerd.

## Scope en bewijsidentiteit

Basis is TRAJECTORY44 `0fef23ae202ebf506f78dcbf890a3f5b2a343bc6`. De observerbron is vóór beide builds en modelroutes vastgelegd in `87e43fd47`. Beide routes herhalen dezelfde oorspronkelijke checkpoint en het reeds bestaande360-stappentraject tot35797,491000009170. De geselecteerde events zijn exact de90 domein3/node50-events van eigen poging36 tot en met125.

De nieuwe observatie leest de bestaande provider-cache en de gekozen sorptietak, registreert de toestand vóór de kopberekening en zet de RATE- en END-fasen naast elkaar. Alle fysieke en numerieke statements blijven ongewijzigd; de read-only extra ENTRY's voeren geen providerberekeningen uit. Er zijn geen extra rateproeven, tijdstappen, scenario's, dt-/tolerantie-/MAXIT-/reductiewijzigingen of brede campagne. `OBSERVATION_CHANGES.patch` en de bronvergelijking in `assess_clock45.py` bewijzen die afbakening.

## Drie verschillende contacten

| Fase | Waarneming bij dezelfde90 events |
|---|---|
| Vóór de kopberekening | Positieve onverzadigde overlap bij1 event; nul bij89. Macroporiewater blijft wel in de cel aanwezig. |
| Geaccepteerde RATE-geometrie | Positieve onverzadigde contactfactor in alle90:0,00851768235 tot0,20977514271. |
| END-geometrie | Onverzadigde overlap nul in alle90; natte macroporiewandfractie blijft0,01655452514 tot0,33770830406. |

De geaccepteerde RATE-geometrie vergelijkt de nog niet bijgewerkte macrovoorraad met de gekoppeld berekende matrix-GWL. Na de voorraadupdate ligt de macrovoorraad binnen6,94e-18 cm op de minimumvoorraad en is de macro-eindwaterstand exact gelijk aan de matrix-GWL. Daardoor verdwijnt de resterende onverzadigde overlap, terwijl een deel van de celwand onder dat peil nog altijd macroporiewater raakt.

Dit verklaart waarom een nul in de END-contactfactor geen zelfstandig criterium is om de reeds lopende contactklok opnieuw te starten of te pauzeren. De klok beschrijft de leeftijd sinds het eerste macroporiewatercontact van het compartiment; de contactweging hoort bij de omvang van de flux en referentie-increment. De primaire definitie en de precieze afbakening staan in `PHYSICAL_CONTRACT.md`.

## Werkelijke sorptie, geen vlag zonder ratebewijs

| Grootheid | Gemeten bereik/waarde |
|---|---:|
| Potentiële sorptierate | 6,276025786669168e-7 tot2,2000681579377526e-6 cm/dag |
| Uitstroomfactor na voorraadbegrenzing | 0,31572287776582575 tot0,8906748291063834 |
| Werkelijke geaccepteerde sorptierate | 2,0690775454763708e-7 tot1,959545330593603e-6 cm/dag |
| Geïntegreerde werkelijke sorptie,90 stappen | 7,408149806275835e-8 cm |
| Geaccumuleerde gebruikte dt | 0,18 dag |

De daadwerkelijke rate is op ieder punt exact de potentiële rate maal de toegepaste uitstroomfactor. De gekozen tak is in alle90 gevallen sorptie; verzadigde uitstroom en de beide instroomtermen op deze node zijn nul. Zowel potentiële als werkelijke rate liggen telkens boven de bestaande eventdrempel1e-7 cm/dag. Dit zijn dus geen gevallen waarin uitsluitend een potentiële vlag overblijft terwijl de voorraadbegrenzing alle daadwerkelijke sorptie wegneemt.

De actuele cache is in alle360 stappen als laatste RATE-aanroep (taak1) herkend, met juiste tijd, gebruikte dt, poging, iteratie, gereedstatus en volledige overeenkomende kopvector. Er wordt geen onbevestigde oude Jacobiaan-cache voor de fasevergelijking gebruikt.

## Klok en contactverliescontrole

De klok stijgt over de90 events van0,07000000000000005 naar0,25000000000000017 dag:0,18 dag, gelijk aan de som van de gebruikte dt's. De theoretische referentie blijft tijdens deze events gelijk wegens de behouden nulweging van het END-contact. De werkelijke sorptie is ondertussen opgenomen in de bestaande gecommitteerde waterinventaris en fluxintegralen; een nul-increment in deze theoretische hulpvariabele is geen ontbrekende waterboeking.

De volgende bestaande stappen leveren een nuttige grenscontrole, zonder nieuwe contextselectie:

| Poging | Werkelijke sorptie | Natte celwand END | Klok na commit |
|---|---:|---:|---:|
| 125 | 5,405058281722153e-7 cm/dag | 0,01655452514 | 0,25000000000000017 dag |
| 126 | 2,9884092096904397e-6 cm/dag | 0,00966837222 | 0,25200000000000017 dag |
| 128 | 8,220038603563489e-7 cm/dag tijdens de stap | 0 | 0 |
| 129 | 0 | 0 | 0 |

Bij128 ligt de macro-eindwaterstand op-66,00074484602969 cm, onder de celondergrens-66 cm. Dan verdwijnen het volledige celwatercontact en het eventgeheugen: klok, referentie en sorptiviteit worden nul. De afhandeling onderscheidt dus nul onverzadigde eindoverlap van werkelijk droogvallen van de cel.

Voor de90 onderzochte events is daarom geen klokwijziging gerechtvaardigd. Deze onderbouwing sluit de specifieke klokvraag uit TRAJECTORY44, maar is geen algemene goedkeuring van elke potentiële eventvlag of van ieder denkbaar contactverlies binnen een tijdstap. De fysische nauwkeurigheid van de afzonderlijke theoretische referentieformule met END-weging is niet opnieuw vastgesteld of gewijzigd.

## O0/O2 en behoud

O0 duurt1,838663 seconden en O2 1,352954 seconden. Beide processen eindigen normaal en ongecensureerd, ruim binnen twintig seconden per route; de bestaande interne zestiensecondenstop,512-commitcap en vaste eindgrens zijn behouden. Er zijn precies twee modelroutes en geen extra provider-evaluaties uitgevoerd.

Alle oorspronkelijke numerieke tekstuitvoer, geaccepteerde pogingregels, budgetten, Jacobianen, volledige geschiedenisreceipts, native contexten, ledger en eindtoestand zijn exact gelijk aan TRAJECTORY44 buiten de rekentijdvelden. Ook de nieuwe360 fasereceipts zijn O0/O2-bytegelijk. De bestaande korte traject- en waterbalanskwalificatie blijft daarmee behouden; er is geen nieuwe volledige periode- of herstartclaim.

Besluit: `PASS_CLOCK_CONTINUATION_JUSTIFIED_FOR_SAME90_CONTACT_EVENTS_O0_O2_NO_CHANGE`. B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; geen canonieke promotie. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd.

`SAME90_EVENTS.csv`, `RESULT.json`, `TRACE_FIELDS.json` en de ruwe uitvoer dragen de controleerbare claims. `assess_clock45.py` analyseert uitsluitend opgeslagen data. `CLOCK45_EVIDENCE.zip` bevat bron, ruwe data en de daadwerkelijke native buildclosure; `EVIDENCE.json` bindt checkpoint en SHA-256. Ieder opgenomen bestand wordt streamend tegen het manifest geverifieerd.
