# DTMIN57 — relatieve stapbegrenzing en backtracking

Het contract is afgebakend: behoud de oorspronkelijke gemengde absolute/relatieve begrenzing en pas daarna de bestaande backtrackingfactor toe op de begrensde richting. Dit verenigt beide doelen zonder nieuwe parameters of versoepelde criteria. De historische specifieke auteursbedoeling is niet gedocumenteerd; het is een onderbouwd minimaal correctiecontract, nog geen solverimplementatie. Zie INTENT_CONTRACT.md voor de exacte activatie, formule en afhandeling van uitputting.

## Gerichte O0/O2-bewijzen

Baseline DIAG56 e225494ed9977f4815612f82077cfa33fb4bf5dd; preregistratie b38fafc27. Twee verse processen op dezelfde eigen oorspronkelijke NATIVE55 D2-checkpoint. Alleen observer-IO toegevoegd aan headcalc; alle andere Fortran-bronnen byte-identiek. De toegevoegde logging schrijft bestaande arrays na een echte vector-evaluatie en wijzigt geen solvervariabele. De rest van de native objectclosure is hash-gecontroleerd hergebruikt; uitsluitend headcalc opnieuw gecompileerd en gelinkt.

| Route | Modeltijd | Volledige proefrecords | Nodes per record | Uitkomst |
|---|---:|---:|---:|---|
|O0 RESTART_D2|1,847 s|227|112|normaal; dezelfde weigering en schaalverzoek|
|O2 RESTART_D2|1,716 s|227|112|normaal; dezelfde weigering en schaalverzoek|

Beide ongecensureerd onder20 s, returncode0. De bestaande IEEE_DENORMAL-melding is behouden. Interne16 s,512commit/4retrygrenzen en alle fysica-, klok-, budget-, dt-, reductie- en convergentieregels blijven behouden. Geen brede campagne of extra modelcontexten.

O0/O2 hebben byte-identieke nieuwe volledige logging. Per route zijn44 oorspronkelijke fysieke/solver/providertekstbestanden byte-identiek aan DIAG56; pogingen zijn exact na uitsluitend het weglaten van hun rekentijdkolom. Installatie, ledger, weigering en rollback blijven gelijk. Geen vervolgcommit, tijdvooruitgang of ledgerintegratie; finale nativecontext verschilt alleen in dt/dtold.

## Beslissende bevinding

De drukhoogtegrens is1 cm absoluut wanneer |H|<1 cm, anders100% relatief. In de extra dertig dtmin-iteraties is de maximale gemengde Newtonstap M slechts0,00006611..0,02277436. De limiter grijpt dus nergens in (alpha0 steeds1). Toch gebruiken zestig proeven in die fase de dtmin-update zonder factor. Bij tien iteraties worden vier volledig identieke proefheads doorgerekend; defactoren1,1/3,1/9,1/27 staan wel in de lus, maar veranderen de proef daar niet. Dit bevestigt en verscherpt DIAG56 met alle112 componenten in plaats van alleen de eerdere gelogde band.

De overige167 proeven gebruiken de gewone update. Alle227 oorspronkelijke updates zijn uit de volledige pre-update heads/richting exact terugberekend (maximale fout0 cm). Hiermee is het onderscheid tussen relatieve limiter en ontbrekende backtracking empirisch vastgesteld. Het is geen effect van native herstart, voorraadcorrectie of een geactiveerde relatieve begrenzing. De eerder vastgestelde buiten-contract voorraadkoppeling blijft een afzonderlijke mogelijke oorzaak van stagnatie.

## Consistente minimale herstelrichting

In de bestaande speciale tak wordt alpha0 éénmaal per Newtonrichting vastgelegd en is alpha(k)=alpha0*3^(-k). De eerste proef en de grens blijven behouden, latere proeven krimpen werkelijk. Buiten die tak verandert niets. Zes formulegevallen toetsen grens, teken, nulrichting, actieve en inactieve limiter. Alle algebraïsche checks slagen. Geen alternatieve heads in een fysieke operator uitgevoerd; geen convergentie- of prestatiewinstclaim voor een gewijzigd model.

De feitelijke routes stoppen nog steeds na30 iteraties op de eerste vervolgstep (node52, Fmax2,1218091917013238e-3) en60 op dtmin (node57, Fmax2,16137288712559e-4). IDecMpRat vraagt1, FrReduQ blijft1. De productvorm is een voldoende afgebakende kandidaat voor een volgende minimale numerieke implementatie, geen toestemming voor andere solverwijzigingen of reductie.

## Status en herstel

Getoetst: observerneutraliteit, volledige oorspronkelijke update, O0/O2-gelijkheid en het algebraïsche samenstellingscontract. Niet geïmplementeerd/getoetst: gecorrigeerde solver, geaccepteerde vervolgstep, gecorrigeerde rollback/retry, volledige periodebalans of algemene herstart. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; canonieke productie/Status-A onaangeraakt.

Herstel via STATUS.json, RESULT.json, INTENT_CONTRACT.md, FULL_STEP_AUDIT.csv, SOURCE_AUTHORITY.json, OBSERVER.patch en ruwe dtmin57_trials.txt per route. assess_dtmin57.py doet geen modelaanroepen. EVIDENCE.json bevat SHA/membercontrole van het streaming-archief.

Compile/link afzonderlijk: O0 2.879 s, O2 2.308 s; dit zijn geen modelroutes.
