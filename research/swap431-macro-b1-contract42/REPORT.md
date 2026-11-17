# CONTRACT42: ABSORPTION-contract rond -60 cm bij oorspronkelijke poging 357

**Voor deze veldroute is de sprong een aantoonbare afwijking van het gedocumenteerde Darcy-contract.** De hele-celuitsluiting is bewust gecodeerd, maar schakelt een positieve laterale contactflux volledig uit in een matrix die nog onverzadigd is. De afzonderlijke verzadigde uitwisseling neemt deze flux niet over. De historische auteursintentie is niet gereconstrueerd; de foutclaim is de afgebakende implementatie-versus-contractafwijking in de onderzochte huidige kandidaat.

O0 en O2 bevestigen dezelfde eindige sprong tot op GWL=-60±1e-8 cm. De numerieke voortzetting van de oorspronkelijke poging blijft na alle herstelde proeven exact gelijk aan NODE41. Er is geen herstelpatch uitgevoerd en geen verbeterde convergentie of volledige periodebalans geclaimd.

## Oorspronkelijke context en bron

Basis is NODE41 `37b828991787fecf876f5c8ea8aa9db3ee7532f6`; broncheckpoint vóór bouwen en rekenen is `07b5d3686`. Beide routes starten op dezelfde native checkpoint t1900=35797 (SHA-256 `21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16`) en herhalen dezelfde eigen kandidaatprefix tot poging357, t1900=35797,487000006880, dt=0,001000001146167051 dag. Het huidige proces bevat het eerdere afgebakende Darcy-contractherstel uit CONTRACT06; de onderhavige uitsluiting van de GWL-cel is daarin niet gewijzigd.

Het primaire fysieke gezag is het oorspronkelijke [SWAP-4-rapport, WER2780](https://edepot.wur.nl/416321#page=102), gedrukte pp.100/106, Eq.6.32/6.57, samen met de werkelijk gebruikte constitutieve parameters en bestaande selectieregels. De lokaal behouden PDF heeft SHA-256 `1cf1c350870fc7f7923dc17878fefa0dd2dc58b40fffb34b8d255d5a7fd2a82e`. De relevante pagina's zijn tekstueel gelezen en fysieke PDF-pagina's102/108 visueel gecontroleerd. Identiteiten en paginaweergaven staan in `sources/`. Andere SWAP5-contactmodellen en hun eventuele correcties worden niet als toelatingsbewijs voor deze kandidaat overgenomen.

## Wat de bron precies doet

`CALCGWL/nodlev` levert de native cel die de geïnterpoleerde GWL bevat. `MACRORATE` neemt die cel over in `ICpTpSatZon`. De bestaande ABSORPTION-loop eindigt op `min(ICpBtDm(id),ICpTpSatZon-1)`; daarnaast bestaat een perched-zoneuitsluiting. Daardoor wordt node47 aan de zijde GWL>=-60 volledig overgeslagen.

SATFLOW zet de uitwisseling op nul als de lokale matrixkop negatief is. De onderzochte kop blijft op beide zijden ongeveer -0,845857 cm. De combinatie van beide uitsluitingen laat hier dus geen alternatieve laterale flux over. Het broncommentaar dat in een deels verzadigde cel geen sorptie wordt beschouwd, beschrijft de codekeuze; de hele ABSORPTION-loop omvat echter ook de Darcy-term.

`ADJUDICATION.md` werkt de concrete tegenspraak met het contact-/drukgradiëntcontract en de grenzen van de beslissing uit. Er wordt geen algemeen oordeel over alle historische configuraties of een toevallige programmeerfout van een bekende auteur gegeven.

## Gerichte tweezijdige proeven

Het behouden levende punt is poging357, iteratie10, na de oorspronkelijke Jacobiaanopbouw. Alle koppen behalve h47 blijven gelijk. h47 wordt verkregen door de oorspronkelijke interpolatie over47/48 te inverteren voor de gevraagde GWL. theta47 wordt met de oorspronkelijke WATCON berekend; de bestaande SwKimpl-regel bepaalt of de geleidbaarheid wordt bijgewerkt. De originele MACRORATE(1) berekent elke proef opnieuw.

Per route zijn er acht extra providerevaluaties: oorspronkelijke basis, drie paren op ±1e-4/±1e-6/±1e-8 cm rond -60 en herhaalde basis. Iedere proef begint uit exact dezelfde herstelde toestand. Er is geen eindige-differentie-Jacobiaan, gewijzigd fysisch alternatief of aanvullende modelvariant uitgevoerd.

| Afstand tot -60 (cm) | Werkelijke D4-rate beneden -60 | Werkelijke D4-rate boven -60 | Bestaande Darcy-kandidaat boven -60 | Geometrisch onverzadigde fractie boven -60 |
|---|---:|---:|---:|---:|
| 0.0001 | 0.05653711061153 | 0.0 | 0.05653519427965 | 0.999950000000 |
| 1e-06 | 0.05653616193143 | 0.0 | 0.05653614276811 | 0.999999500000 |
| 1e-08 | 0.05653615244558 | 0.0 | 0.05653615225394 | 0.999999995000 |

Rates zijn cm/dag. Aan de onderste zijde is de domein4-uitstroom exact gelijk aan de onafhankelijk gereconstrueerde bestaande Darcy-term, inclusief de bestaande SorpFac. Aan de bovenste zijde wordt dezelfde positieve kandidaat volledig overgeslagen. De positieve drukgradiënt bedraagt bij de kleinste offset ongeveer9,96914 cm; de matrix is met thetaS-theta≈6,16e-7 nog onverzadigd. Macroporiewater staat boven de hele celwand. Alle vijf domeinen hebben in de proeven instroom-/uitstroomfactor één en FrReduQ=1.

Zelfs bij een geometrische weging naar het nog onverzadigde wanddeel blijft bij de kleinste offset circa0,05653615197 cm/dag over. Die berekening controleert uitsluitend dat het contact niet verdwijnt; zij is geen geïmplementeerde vervangende fluxwet. De exacte grens GWL=-60 en algemene gedeeltelijke contactgeometrie zijn niet gekwalificeerd.

De afzonderlijke verzadigde uitstroom en instroom op node47 zijn in alle acht proeven nul. Het gemeten nulpunt wordt dus niet verklaard door een vloeiende overdracht naar SATFLOW, een voorraadbegrenzing, reductie of matrixverzadiging. Het uiteindelijke oordeel blijft specifiek gericht op het ontbrekende Darcy-contact; dit is geen watercreatieclaim of nieuwe algemene sorptiehistoriewet.

## Herstel en onveranderde voortzetting

De geselecteerde SENSE23-procestoestand omvat20.347.880 bytes. Een aanvullend diagnostisch streamrecord omvat3.247.712 bytes met de canonieke numerieke cache en de observatiecache. Beide worden vóór iedere proef en na afloop bytegelijk hersteld; ook de erkende IEEE-vlaggen en opgeslagen IEEE-status worden teruggezet. Alle negen herstelcontroles slagen bij O0 en O2. Het uitgebreide streamrecord is uitsluitend voor deze diagnose en wijzigt geen native herstartformaat.

De eerste en laatste basisproef leveren exact dezelfde rates en metadata. Alle bestaande NODE41-tekstuitvoer, de hele pogingtrace buiten rekentijd, beide Jacobiaantraces, de356 voorafgaande gecommitteerde budgetregels, de ledger en de oorspronkelijke MAXIT-afwijzing op node47 zijn na de proeven exact behouden. De oorspronkelijke vector/provider-tellers blijven105; de acht extra rechtstreekse MACRORATE-calls worden apart geregistreerd. De proefrates worden niet gecommitteerd.

O0 duurt2,167346 seconden en O2 1,700457 seconden. Beide routes eindigen normaal, ongecensureerd en binnen twintig seconden; de bestaande interne zestiensecondenstop is behouden. Alle getoetste numerieke uitvoer, probepunten en snapshotbestanden zijn O0/O2-bytegelijk buiten de rekentijdvelden.

## Besluit en resterende grenzen

Uitkomst: `BOUNDED_DOCUMENTED_DARCY_CONTRACT_DISCREPANCY_CONFIRMED_NO_CORRECTION_IMPLEMENTED`. Een minimaal herstel moet het bestaande onverzadigde contact correct afbakenen en de overgang met SATFLOW sluitend houden. De precieze contactweging, sorptiehistorie, afgeleiden en het gedrag op de grens vragen hun eigen implementatie en toets. Alleen de bestaande Jacobiaanvoorwaarden verruimen herstelt dit ontbrekende providercontact niet.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. Er is geen herstelpatch, nieuwe convergentiekwalificatie, volledige BAL-periode, nieuwe native herstart, brede campagne of canonieke toelating. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd; fysica, input, toleranties, MAXIT, dt- en reductieregels zijn behouden.

`PAIRED_LIMITS.csv`, `RESULT.json`, `TRACE_FIELDS.json` en de ruwe uitvoer dragen de controleerbare claims. `assess_contract42.py` analyseert uitsluitend opgeslagen uitvoer. `CONTRACT42_EVIDENCE.zip` bevat bron, ruwe data, relevante primaire paginaweergaven en de werkelijke buildclosure; `EVIDENCE.json` koppelt checkpoint en SHA-256. De sealer verifieert alle opgenomen bestanden streamend tegen hun manifest.
