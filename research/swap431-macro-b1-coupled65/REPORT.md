# SWAP431-MACRO-B1-COUPLED65 — BOUNDED_UNRESOLVED

De ontbrekende directe vergelijking is uitgevoerd op precies één eerder opgeslagen
live D2-toestand. Fresh gekoppelde acceptatie en de bestaande geïntegreerde
massaguard slagen, maar de retry na echte afwijzing is **niet exact gelijk** aan
de kleinere stap uit de onaangeroerde geaccepteerde begintoestand. Daarom geen
gekwalificeerde B1-referentie of productiepromotie. Het kleine verschil bewijst
op zichzelf geen wetenschappelijk ongeldige oplossing; het bewijst evenmin de
gevraagde volledige ownership-/rollback-/reproduceerbaarheidskwalificatie.

## RECONCILE

Canonical na fetch: `472aa69611d5168cdc8d2dd4322669851c442df6`.
De publicatiereconciliatie van 19 november 2026, MACRO-AUDIT02
`CAUSAL_DISPOSITION.md` op origin/research/macro-audit02-causal, ACCEPT01 en
ACTIVE27 zijn gelezen. De bekende flunsatok(3)-bevriezing is niet heronderzocht.
Het historische SWAP4.3.1-traject is geen wetenschappelijke waarheidsmaatstaf.

ROLLBACK49 kwalificeerde een echte weigering/directe retry bij lege CONTACT47-
scratch, niet bij actieve nieuwe correctie. De latere reeks SELECT50 tot en met
COMBINED63 is gereconcilieerd; exacte statusidentiteiten staan in
RECONCILIATION.json. COMBINED63 `caabd53a52a6e919fbcaf213d6af1c0a2ac4a3a5`
is de meest recente relevante positieve bounded kwalificatie: huidige gestempelde
numerieke payload, originele grotere weigering, ongereduceerde dtmin-retry,
fresh eindcontrole, hostcommit en onafhankelijke waterinventaris op O0/O2.
Eigen fresh vervolgcheckpoint en directe-kleinere-retryvergelijking bleven open.

Experimentele bron vastgepind op REJECT64
`15d14a7b5679b6e11a97414e29a09738e09b9a29`. Zijn STATUS stond toen nog op
PREREGISTERED, maar de drie resultaatcommits en SELECTION_PROGRESS registreerden
al drie geaccepteerde voorstellen en geen geschikte V-afwijzing. Tijdens deze
proef is REJECT64 afgerond in `95a61203d345ccbf2c8f5851c37a0bb138a00835`:
vier normale routes inclusief O2-bevestiging; dezelfde negatieve conclusie.
Dat is meegenomen zonder lopende werkcheckout of andere chat te wijzigen.
Geen vierde voorstel, nieuwe toestand of grensintervalzoektocht uitgevoerd.

## QUALIFY — vaste toestand en uitvoering

NATIVE55 D2 `candidate.end`, SHA256
`59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e`,
geaccepteerde oorsprong t1900=35797.290431125148. De toestand is afgeleid van
de bestaande ACTIVE27/SELECT50-contextreeks. De selectorlabels hebben een oudere
t/dt; de daadwerkelijk ingelezen native-tijd en de pogingjournalen zijn hier de
autoriteit. Geen replay van 481 dagen en geen nieuwe contextselectie.

Vier verse processen: CHAIN en DIRECT op O0 en O2. CHAIN gebruikt exact het
vastgelegde oorspronkelijke voorstel dt=2.0951312035156963e-5 dag. Het wordt
werkelijk afgewezen na 30 uitgevoerde iteraties (DO-teller31), Fmax
2.1198336748706748e-3 en somF8.414477305576075e-3 cm/dag. De normale interne
TimeControl(5)-route kiest dt=1e-5. DIRECT begint onafhankelijk uit hetzelfde
native bestand en krijgt uitsluitend deze daadwerkelijk waargenomen retry-dt.
Het oorspronkelijke voorstel wordt dus niet aangepast om afwijzing te forceren.

Compiler: GNU Fortran16.2.0, MSYS2 Rev4. Bestaande gehashte REJECT64 O0/O2-
executables zijn hergebruikt, geen nieuwe build. Volledige compilercommando's,
bronhashes, executablehashes en geërfde COMBINED63-buildclosure staan via
SOURCE_IDENTITY.json en de INPUT.json-records vast. De REJECT64-harness verschilt
van COMBINED63 uitsluitend door begrensde initiële dt-invoer; CHAIN reproduceert
de COMBINED63-fysieke uitvoer en native eindpacket exact. De bron is dus niet
stilzwijgend vervangen door een nieuwe algemene solver.

De kandidaat bevat de ACCEPT01-V1-eindcontrole en de reeds vastgelegde B1-
ownership-/numerieke reparaties tot COMBINED63, waaronder de begrensde rang2-
aanvulling op de bestaande tridiagonale solve. Deze unit voegt geen Jacobiaan
of solver toe. SATFLOW/ABSORPTION/VOLUNDR, klok, hostintegratie, massaguards,
MAXIT30/60, backtracking, reductiewet en tolerantiecriteria blijven gelijk.
De gebruikte HeadCalc bevat bij voorlopige convergentie opnieuw
`vector_F(1,hgrad)` en alle oorspronkelijke lokale/hoofd-/pond-/somcriteria.

Wandtijden: O0CHAIN1.323s, O0DIRECT0.820s, O2CHAIN1.482s, O2DIRECT0.825s.
Alle vier normaal en ongecensureerd, externe grens20s, interne16s/4pogingen
ongewijzigd. IEEE_DENORMAL wordt door alle processen gemeld en behouden;
geen numerieke uitzonderingsinstellingen aangepast.

Procesnotitie: het vaste vier-routecontract en de runner waren vóór O0CHAIN
geschreven. De eerste Git-add weigerde de nieuwe map wegens sparse checkout;
de shell ging door naar O0CHAIN. Commit577e678c4 bewaart het ongewijzigde
contract vóór de andere drie routes, niet vóór de eerste. Dit is geen claim
van een Git-voorregistratie van alle vier routes. Het opslagpad van de runner
is na uitvoering naar de gealloceerde evidencewerkmap verplaatst; modelaanroep
en selectie veranderden niet en er zijn geen extra modellen gestart.

## ANALYZE — acceptatie en water

O0 en O2 zijn binnen iedere route exact gelijk voor alle vergeleken niet-timing-
tekstvelden, pogingvelden buiten wandtijd en het native eindpacket. RESULT.json
noemt iedere werkelijk vergeleken file. Iedere geaccepteerde stap gebruikt drie
iteraties, één afsluitende fresh controle, IDecMpRat0, FrReduQ1 en één hostcommit.

| Grootheid | CHAIN-retry | DIRECT |
|---|---:|---:|
|Fmax [cm/dag]|3.044456621352498e-8|3.0444564034712296e-8|
|somF [cm/dag]|2.0918085756152195e-7|2.0918046662162138e-7|
|matrixvoorraadverschil [cm]|-2.2257545273197916e-6|-2.2257545273197916e-6|
|macrocompartimentverschil [cm]|-6.358490123801715e-7|-6.358460167625287e-7|
|externe netto-integratie [cm]|-2.8616056316129105e-6|-2.8616026359441764e-6|
|onafhankelijke inventarisfout [cm]|2.0919129474248157e-12|2.0918618560915032e-12|

Alle112 residuen voldoen aan1e-6; de som voldoet aan1e-5 cm/dag. De onafhankelijke
waterinventaris komt uit theta/dz/matrixfractie en alle macrocompartimenten,
met pond en canopy expliciet beide nul, tegenover de ongewijzigde externe
hostfluxen. Macro_sat wordt niet nogmaals bij de compartimentvoorraad opgeteld.
Beide fouten liggen onder dt*CritDevBalTot=1e-10cm. De inventaris sluit aan op
somF*dt tot minder dan2e-15cm. Afzonderlijke domeinfouten zijn kleiner dan
1.08e-16cm. Dit is een substepinventaris; geen volledige periode-BAL-kwalificatie.

## ANALYZE — rollback, ownership en reproduceerbaarheid

De CHAIN-poging heeft24 actieve W-aanvullingen in de afwijzing; de geaccepteerde
retry heeft W/V/V. DIRECT heeft ook W/V/V. Er is geen echte afwijzing met actieve
V-correctie beschikbaar binnen de bestaande begrensde selectie; dat blijft open.

Na de echte afwijzing is de vastgelegde native context terug op de oorspronkelijke
toestand, behalve de bedoelde dt/fldtmin. De ledger is byte-identiek vóór retry;
er is dus geen dubbele integratie van de geweigerde poging. Tussen CHAIN-retry
en DIRECT zijn de volledige vastgelegde native-contextvelden en opgeslagen
macro-oorsprong exact gelijk, evenals de beginledger en het initiële native bestand.
Dat kwalificeert deze velden; het is geen bewijs dat alle lokale SAVEs, rates en
eventwerkvelden identiek zijn.

De bredere inventorydump verschilt vóór HeadCalc wel in macro_in_vert,
macro_exchange, macro_rapid, matrix_exchange, boundary_rates en twee eventflags
(platte indices194/238, nulgebaseerd). De cache-readiness is in beide routes
ongeldig; metadata van de oude grotere evaluatie en lege initiële metadata zijn
niet gelijk. Het eerste node_iterations-record verschilt al bij iteratie0.
Deze velden zijn niet als causaal bewezen bestempeld en niet willekeurig hersteld.
Sink, source en qroot in de uiteindelijke solverrecord zijn gelijk. De directe
route doorloopt dezelfde ongewijzigde hostlus; er is geen bewijs verzameld dat
een specifieke ontbrekende voorbereiding of SAVE de oorzaak is.

Na acceptatie verschilt h maximaal5.6904841301275155e-6cm, Qexchange maximaal
8.6299368033671e-8cm/dag, en de bottomflux2.995668734601109e-7cm/dag.
De native macrovoorraad verschilt maximaal2.9956037650435974e-12cm,
ZWaLevDm1.4978240869822912e-10cm. Ook de definitieve ledger en het eigen
native packet verschillen. CHAIN volgt exact COMBINED63 met SHA256
`7df2ffc6fd0ef85c129a9b91259bfa9baa0c234665a1b8e1d9cadb2f56d2e09e`;
DIRECT levert op beide optimalisaties
`d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7`.
Alle verschillen, hun indices en maxima zijn in RESULT.json behouden.

## REPAIR / PERSIST / CLOSE

Geen reparatie: er is een onderscheidend, deterministisch verschil, maar geen
causaal geïsoleerde wijziging die een ingreep rechtvaardigt. De bekende
bevriezing opnieuw onderzoeken zou deze open vraag niet beantwoorden.

Besluit **BOUNDED_UNRESOLVED**. De gezamenlijke vijfdelige gate is niet gehaald:
fresh residual en massaguard slagen, de named-state rollback is ondersteund,
maar volledige ownership en exacte onafhankelijke retry-equivalentie blijven
onbewezen. Algemene afwijzing van V1 of de oorspronkelijke fysica volgt hier niet
uit; promotie tot migratiereferentie volgt er evenmin uit.

Alle nieuwe ruwe processen, inputs, begin-/eindbinaries en negatieve verschillen
zijn lossless behouden in COUPLED65_RAW.zip. manifest.json verwijst naar unieke
SHA256-blobs; identieke gegevens staan eenmaal in de capsule. EVIDENCE.json
bindt de inhoud, SOURCE_IDENTITY.json bindt de bestaande compiler/build/bronnen.
assess_coupled65.py doet nul modellen en reconstrueert de beslissing.
De capsule is onafhankelijk uitgepakt en opnieuw beoordeeld: RESULT.json blijft
byte-identiek. Beide daadwerkelijk gebruikte executables zijn ook rechtstreeks
in het centrale REJECT64-Gitarchief op95a61203 teruggevonden en gehashverifieerd.
DEPENDENCIES.json en VERIFICATION.json leggen die controle vast.

Herstel: start de eigen opslaglifecycle, gebruik een sparse checkout van deze
branch met COUPLED65 en COMBINED63, alloceer een tempmap, herstel de capsule via
unpack_coupled65.py en geef die datamap aan assess_coupled65.py. Voor nieuwe
modeluitvoering moeten de exact gehashte oude executableclosures worden hersteld
en beschermd; de oude lokale paden zijn geen blijvende autoriteit.

Voor de macroporiënmigratie blijft V1 plus de begrensde vervolgcorrecties een
onderzoekskandidaat met expliciete uitsluitingen. De volgende inhoudelijk veilige
stap is een afzonderlijk vooraf begrensde causale vergelijking van de allereerste
retry-evaluatie, met volledige processcratch en identieke directe voorbereiding.
Die nieuwe proef is hier niet gestart. Geen productie-/canonicalwijziging,
volledige CI-campagne, algemene solvercampagne of481-daagse simulatie.

De uitgevoerde bounded unit is hiermee gesloten met een open wetenschappelijke
gate; dit is geen nog draaiende proef. Na commit/push en centrale objectcontrole
worden uitsluitend de eigen reproduceerbare case-/uitpakkopieën en schone eigen
werkcheckout via de gedeelde cleanup.py-lifecycle vrijgegeven. De gebruikte
andere-chatbuilds en invoer worden alleen ongeprotect voor deze chat. Geen andere
chat, onbekende legacyfolder of wetenschappelijk bewijs wordt vrijgegeven.
