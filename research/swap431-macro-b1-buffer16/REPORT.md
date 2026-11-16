# BUFFER16 — exacte gebufferde capture en volledige geselecteerde waterbalans

**PASS voor de volledige geselecteerde waterinventaris van1998-01-01 tot de voltooide daggrens na2januari, met vaste kandidaat en O0/O2.** Gebufferde budgetregistratie behoudt exact de bestaande regels. Beide prefixroutes bereiken t1900=35797 binnen twee seconden. De onafhankelijke periodebalans inclusief canopy sluit met5,965585×10⁻⁷cm afwijking. Dit is geen algemene wetenschappelijke toelating of officiële referentiepromotie.

Een concrete bestaande uitvoerbeperking blijft apart: de native BAL-opslagregels laten canopywater weg terwijl de fluxregels canopyverdamping aftrekken. De onafhankelijke volledige waterinventaris is gekwalificeerd; die BAL-presentatie is niet als complete opslagboekhouding toegelaten.

## Afbakening en enige uitvoeringswijziging

Basis is COST15 `a8fb68ff1819838b8701da0effea03c4fe1c6f54`, met precies de PREFIX14-kandidaat en bronnen. Canonical blijft `f1883e6fae59658112f6b5750c395a1b54543ed2`. Alle wijzigingen staan uitsluitend in de nieuwe onderzoeksmap. B0, B1.12, canonical, release en andere werkstromen zijn ongewijzigd.

Alleen de levensduur van de diagnostische schrijfstroom verandert. `step_budget.txt` wordt eenmaal geopend, dezelfde oorspronkelijke list-directed WRITE schrijft exact dezelfde32primitieve velden, iedere128commits wordt geflusht en bij het voltooide daggrenscheckpoint wordt het bestand gesloten. `buffering.patch` toont deze wijziging. De I/O-tellers sturen geen modelbeslissing. Fysica, Darcy-/sorptieformulering, Newton, criteria, dtgrenzen en reductiewet zijn byte-ongewijzigd ten opzichte van PREFIX14. De extra kostentellers van COST15 zijn niet nodig en niet opgenomen.

O0 behoudt alle770oude PREFIX14-budgetregels exact; O2 behoudt alle787. De complete nieuwe1453regels zijn onderling bytegelijk tussen O0/O2. Alle meetvectors zijn eveneens exact. Er is geen lagere uitvoerprecisie, reductie van de budgetinhoud of andere kandidaat gebruikt om de route te versnellen.

## Uitgevoerde routes

| Route | O0 | O2 |
| --- | ---: | ---: |
| Ononderbroken oorspronkelijke prefix + checkpoint + eerste vervolgstep | 1,597s | 1,690s |
| Verse native eigen herstart + eerste vervolgstep | 0,372s | 0,386s |

Daarnaast stopt één O2-initialisatie met opzettelijk onvolledige dekkingsmetadata vóór installatie. Totaal vijf routes, geen censuur, alle onder twintig seconden. Er is geen variantzoektocht of481-daagse campagne. De eerder toegestane gerichte tweedaagse prefix is nu voltooid; dit is geen uitbreiding van de geselecteerde periode.

De vergelijking met de eerdere20s-censuur betreft deze lokale instrumentatie/omgeving. Zij is geen universele portable solverbenchmark. De volledige prefix is nu wel aantoonbaar voltooid onder de bestaande limiet.

## Werkelijke oorsprong, kandidaat en periode-output

De route begint koud op t1900=35795, met de Darcycorrectie actief vóór de eerste headcalc en ononderbroken actief tot35797. Er worden geen oude afgeronde V1-cumulatieven ingelezen, geen fysieke bootstrapbestanden zonder historie gebruikt en geen beginvoorraden handmatig herijkt. Alle1453gecommitteerde budgetregels hebben FrReduQ=1.

De exacte beginvoorraden zijn matrix153,08077642218285cm, macro-MB1,582cm en macro-IC0,04949324324324319cm. Macro totaal is1,631493243243243cm. Dit zijn gemeten oorspronkelijke cold-initwaarden van deze route, niet de afgeronde historische CSV-invoer.

De bestaande geselecteerde uitvoerinstellingen zijn behouden: BAL/BLC/BMA aan, DATEFIX2januari en TENDJan3 voor het laden van de aansluitende dag. De normale oorspronkelijke host voert op35797 de echte geplande periode-uitvoer uit. Er is geen tijdelijke ioutdat=2-rendererprobe meer. De checkpointledger toont de werkelijk verhoogde uitvoerteller2. BAL drukt Jan1–Jan2 af; de oorspronkelijke BMA gebruikt bij diezelfde middernacht zijn eindtijdlabel Jan3. Dat laatste is het eindpunt van het hier gebruikte interval, geen derde gesimuleerde balansdag. De labels zijn niet stil herschreven.

## Onafhankelijke periodebalans

De controle reconstrueert de matrixverandering uit begin-/eindtheta, dikte en matrixfractie, de macroverandering uit de vijf echte domeinvoorraden en de canopy-/pondverandering uit hun afzonderlijke voorraden. Externe hoeveelheden worden onafhankelijk uit de1453primitieve werkelijk gebruikte debieten en werkelijke dt opgeteld. Iedere macro-domeinbalans wordt apart gecontroleerd; interne matrix-macrouitwisseling vervalt in het gecombineerde externe saldo.

| Grootheid | Gemeenschappelijk O0/O2 |
| --- | ---: |
| Matrixvoorraadverandering | +0,7638329204791712cm |
| Macrovoorraadverandering | +0,3870080119936092cm |
| Pondvoorraadverandering | 0cm |
| Canopyvoorraadverandering | +0,00259260181361223cm |
| Netto externe hoeveelheid, bruto canopygrens | +1,1534329377278922cm |
| Volledig inventarissaldo minus externe hoeveelheid | **+5,965585×10⁻⁷cm** |
| Grootste afzonderlijke macro-domeinafwijking | 1,12×10⁻¹⁵cm |

Dezelfde afwijking volgt wanneer de canopy buiten het systeem wordt gehouden en werkelijk netto regen/irrigatie als invoer wordt gebruikt. De originele totale residugrens is1×10⁻⁵cm/d; de integraal daarvan over de werkelijk uitgevoerde dt geeft circa2×10⁻⁵cm als ongewijzigde periode-envelop. Het resultaat ligt daar ruim onder. Er is geen nieuwe ruimere tolerantie toegevoegd. De afwijking komt bovendien, met tegengesteld teken en alleen decimale afronding, overeen met de som van de twee oorspronkelijke dagelijkse CSV-BALDEV-waarden. Dit is geen claim van exact nul.

De cumulatieve providerwaarden voor regen, irrigatie, runon, canopyverdamping, pond-/bodemverdamping, wortelonttrekking, bodemflux, drainage, SSDI en snelle macrodrainage worden afzonderlijk vergeleken met hun primitieve integralen. Macro-topinstroom en netto uitwisseling per MB/IC worden eveneens geverifieerd. De geprinte BMA-nul is dus niet als enige balansbewijs gebruikt.

## Complete native historie en periodereset

De eerder geïmplementeerde V4-metadata is nu werkelijk uitgeoefend: exacte oorsprong35795, gedekt eindpunt35797, complete historie en `PATCH_FROM_BALANCE_ORIGIN`. Het native eigen bestand en de volledige ledger worden vers ingelezen. Checkpoint versus installatie, context vóór headcalc en gecommitteerde fysieke/temperatuur-/gewas-/uitvoertoestand na de eerste nieuwe-dagstap zijn bytegelijk aan continu. De oorspronkelijke normale periodereset wordt uitgevoerd; de nieuwe macrobeginvoorraad wordt de werkelijke voorraad op35797. Er is geen vergeten eerdere historie meer in de geselecteerde periode.

Het O0/O2-eigen bestand is bytegelijk. Een bestand waarin alleen de volledigheidsmarkering wordt weggehaald, wordt expliciet afgewezen vóór installatie. Dit kwalificeert deze ene oorsprong/eindfase en eerste reset; het is geen algemene levenscycluskwalificatie van de metadata na latere perioden of willekeurige invoerwijzigingen.

## Afzonderlijke BAL-presentatiebeperking

De oorspronkelijke `swapoutput.f90`-routine OUTBAL schrijft opslag als matrix+pond+macro+sneeuw. SICACT staat daar niet bij. Voor SWINTER=3 bevat CAINTC juist de verdamping uit de canopy; de getoonde fluxsom gebruikt bruto regen minus die verdamping. Het oorspronkelijke bruto BAL-saldo zonder canopyopslag wijkt daardoor hier **−0,002592005255cm** af, vrijwel precies de ontbrekende canopyvoorraad minus de kleine numerieke waterafwijking. Tweedecimale opmaak verbergt dat in de gedrukte tabel.

Er is geen fysieke lekkage of native herstartverlies uit afgeleid: de onafhankelijke canopy-inclusieve balans en de consistente netto-grens sluiten wel. De native BAL-presentatie is binnen deze uitsluitend op buffering gerichte wijziging niet aangepast. Zij krijgt geen volledig opslagboekhoudings-PASS. Het numerieke RESULT.json rapporteert het juiste volledige saldo en de afzonderlijke geobserveerde beperking; oorspronkelijke rapportage en kwalificatie worden niet verward.

## Besluit en herstelpad

Status blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS. De concrete historische lacune voor deze geselecteerde vaste kandidaatperiode is gevuld en de onafhankelijke volledige waterbalans slaagt met O0/O2. Dit promoveert geen481-daagse route, andere modi, algemene wetenschap, bestandsappend/PEARL-keten of de oude BAL-canopyboekhouding.

`assess_buffer16.py` herbeoordeelt zonder modellen. STATUS.json, RESULT.json, buffering.patch, ruwe exacte stapbudgetten, echte natuurlijke periode-uitvoer, eigen bestanden en native compile/link-closure zijn vastgelegd. Alleen een concreet afgebakende nieuwe vraag rechtvaardigt vervolgwerk; er is geen automatische brede campagne geselecteerd.
