# DTMIN58 — minimale implementatie en convergentietoets

Het DTMIN57-productcontract is geïmplementeerd en werkt in de echte solver: de bestaande begrensde Newtonrichting wordt nu ook in de dtmin-tak met de backtrackingfactor vermenigvuldigd. De gerichte D2-vervolgstap convergeert daarmee nog niet. O0/O2 geven exact dezelfde fysieke sporen en dezelfde werkelijke afwijzing. Geen andere solveraanpassing of tuning uitgevoerd.

## Afgebakende wijziging

Baseline DTMIN57 d6f3285f81bae950cdb79ed59103e9e01735cf7e; preregistratie 178b70fd2. Alleen in de bestaande tak `fldtmin .AND. numbit>MaxIt` is één uitdrukking gewijzigd:

```fortran
! voor
h(i) = hold(i) - difh(i) * factmax1
! na
h(i) = hold(i) - (difh(i) * factmax1) * factor
```

De eerste proef blijft behouden. Activatie, limiterberekening, gewone update, Jacobiaan, guards, lijnproef-/iteratiegrenzen, laatste-proefafhandeling, convergentiecriteria, dt, reductieverzoek en budgetbeleid blijven gelijk. De volledige DTMIN57-observer is onveranderd behouden. Een bronassertie bewijst dat uitsluitend deze ene uitdrukking verschilt; alle andere Fortran-bronnen zijn byte-identiek. Dit is geïsoleerde B1-onderzoekscode, geen wijziging of toelating in canonieke productie/Status-A.

## O0/O2-routes

Exact twee verse RESTART_D2-processen vanaf dezelfde oorspronkelijke NATIVE55-eigen checkpoint. O0 en O2: normale ongecensureerde afloop, returncode0, onder hard20 s per route en met originele interne16 s/512commit/4retrygrenzen. Geen brede campagne of extra contexten. De NATIVE55-objectclosure is hash-gecontroleerd hergebruikt; alleen headcalc herbouwd en opnieuw gelinkt.

| Route | Modeltijd | Eerste poging | dtmin-poging | Hostcommits vervolg |
|---|---:|---|---|---:|
|O0|2,277 s|30 iteraties, weigering|60 iteraties, schaalverzoek|0|
|O2|1,917 s|30 iteraties, weigering|60 iteraties, schaalverzoek|0|

Bestaande IEEE_DENORMAL-melding bewaard. Compilatie/link apart geregistreerd; geen modeltimeout en geen extra run voor bewijsgeneratie.

## Het correctiecontract werkt

Alle254 echte lijnproeven zijn met alle112 componenten gereconstrueerd. De gewone update of de speciale productupdate klopt exact met de gelogde heads (maximale formuleafwijking0 cm). De eerste168 volledige proefrecords zijn exact gelijk aan DTMIN57, inclusief alle proeven van poging1, de eerste30 dtmin-iteraties en de eerste proef van iteratie31. De eerste afwijking ontstaat precies op poging2/iteratie31/proef2, waar de eerder genegeerde factor voor het eerst effect moet krijgen. Alle oude numerieke diagnostics over poging1 en de eerste30 dtmin-iteraties zijn eveneens exact gelijk.

De dtmin-tak bevat nu87 werkelijke lijnproeven in iteraties31..60, zonder identieke herhaalde proefheads binnen een Newtonrichting. Richting en beginheads blijven binnen elke zoeklus vast; de effectieve stapnorm voldoet aan de bestaande grens en krimpt met factor. De limiter zelf grijpt ook in dit gewijzigde traject niet in (M tussen2,1240390164810365e-5 en0,0006348700039836746, alpha0 steeds1). De implementatie is fysiek alleen in deze inactieve-limitercontext getoetst; een modelgeval met alpha0<1 is niet geselecteerd. De DTMIN57-algebraïsche grensgevallen blijven afzonderlijk formulebewijs.

Er zijn nu254 lijnproeven en256 initiële/proef-vector-evaluaties over beide pogingen, tegenover227 en229 voorheen. Effectief terugzoeken verwijdert zinloze duplicaten maar garandeert geen lager totaal aantal evaluaties. De tijden zijn geen vergelijkbare snelheidsbenchmark.

## Convergentie verbetert, criteria blijven onvervuld

Residu-eenheid cm/dag. De eerste poging op dt2,0951312035156963e-5 blijft volledig gelijk: Fmax2,1218091917013238e-3 op node52, som8,637543343477884e-3. Na verkleining blijft dt op de oorspronkelijke ondergrens1e-5.

| dtmin-maat | DTMIN57 | DTMIN58 |
|---|---:|---:|
|Beste iteratie-eind Fmax|1,6603248028879136e-5 (iter8)|6,838039125461881e-6 (iter53)|
|Laatste Fmax|2,16137288712559e-4|2,2491570572547026e-5|
|Node laatste maximum|57|52|
|Laatste som F|1,5179109854425075e-3|9,643422493501127e-5|
|Echte lijnproeven dtmin|141|168|
|Iteraties met4proeven uitgeput|15|11|

Eind-Fmax verbetert factor9,6097; eindsom factor15,7404. Maar de lokale grens blijft1e-6 en de totale grens1e-5. Ook het beste Fmax voldoet niet. Er is geen voorlopige convergentie of fresh acceptance; na60 iteraties blijft uitkomst4 staan. Het globale residumaximum op de dtmin-iteratie-einden ligt59maal op node52 en éénmaal op57.

De bestaande guards van de niet-lokale Jacobiaan-aanvulling blijven alle90 keer geldig-provider/-3, dus buiten het bestaande toelatingscontract. Dit verklaart geen unieke resterende oorzaak en rechtvaardigt geen guardversoepeling. De eerder vastgestelde positieve instroom/voorraadkoppeling blijft een afzonderlijk gerichte onderzoeksvraag.

## Werkelijke weigering, herstel en behoud

De echte dtmin-poging vraagt IDecMpRat1/FlDecMpRat; FrReduQ blijft1. Er is geen gereduceerde rekenstap uitgevoerd. De ongewijzigde harness herstelt de proefstaat en stopt met NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED. Finale nativecontext is exact gelijk aan het begin behalve dt/dtold; ledger is byte-identiek. Geen tijdvooruitgang, voorraadcommit of integratie; step_budget en inventory_trace zijn leeg. Nul vervolg-hostcommits.

O0/O2 zijn byte-identiek in alle fysieke tekstbestanden inclusief volledige nieuwe proeflogging; pogingregistraties zijn gelijk na weglaten van alleen rekentijd. De operatorresidusom is onafhankelijk gecontroleerd (maximale afwijking2,78e-17). Geen versoepelde fysica-, klok-, waterbalans-, tolerantie- of budgetregel.

Getoetst en gekwalificeerd: minimale productupdate in deze D2-context, activatiegrens, eerste-proef-/voortrajectbehoud, feitelijke afwijzing en terugkeer naar native oorsprong. Niet gekwalificeerd: convergentie, geaccepteerde vervolgstep/commitwaterbalans, nieuwe geforceerde afwijzing met directe kleinere retry, volledige periodebalans of algemene native herstart. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS.

## Vervolg en herstel

Geen extra parameter- of oplossingscampagne gestart. Volgende gerichte vraag: de resterende node52-weigering in het gewijzigde dtmin-traject afbakenen met de bestaande operator-/iteratie-/voorraadsporen, inclusief de positieve instroom en wisselende minimumtak. Het effectieve backtrackingherstel is hiervoor een kandidaatbasis; het is geen volledige convergentieoplossing.

Herstel via STATUS.json, RESULT.json, CONTRACT.md, MINIMAL.patch, STEP_AUDIT.csv, ITERATION_PROGRESS.csv, assess_dtmin58.py en CODEX_FOLLOWUP.md. EVIDENCE.json bindt alle bronnen, ruwe routes en buildclosure aan een streaming-gecontroleerd archief.

Gemeten compile/link: O0 1.017 s; O2 2.018 s. Analyse/seal zijn modelvrije controles.
