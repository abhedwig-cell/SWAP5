# Viermaal natte proef: verzadiging en ontwatering gerepareerd

22 oktober 2026. Lokale aanvulling op draft PR #1361, bronbasis
`bb0d816176d33254e3f4fb6d3d7e2a0563f663c5`. Geteste productieaanvulling:
`a1c127a6e6ad6c09c2133eff27d85a3f3d1005a7`. Canonical gecontroleerd op
`46ad96ee2cc65fdee48a1f3b47e3290f86f7ffd6`. Niet gepubliceerd of gemerged.

## Oorzaak

De oorspronkelijke proef stopte op dag 35. De eerdere reparatie behandelt regen,
verdamping, oppervlakteberging en afstroming tijdens elke Richards-proefstap,
maakt de Mualem-doorlatendheid continu tot verzadiging en gebruikt bijpassende
Newton-afgeleiden en een full/half-tijdsfoutschatter. Het oude Ksat-afkappunt
maakte in dit profiel een sprong van circa 4.57005 naar 4.75 cm/dag.

De nieuwe echte viermaal-natte proef bij 1e-6 cm onthulde een tweede blokkade:
dag 43, intern 42.287931002257956 dag. De onderste drukhoogte was positief
2.1596686945289869e-13 cm en moest negatief worden. Alle 33 pogingen werden door
de bodemoplosser afgewezen; er waren geen massa- of tijdsfoutafwijzingen in die
laatste reeks. Ook 80 Newton-iteraties of 64 backtrackingpogingen losten de kleine
reproducer niet op. De Mualem-afgeleide wordt aan de onverzadigde kant bij nul
zeer groot. De Newton-stap schoot voorbij de zeer kleine negatieve oplossing.

## Code

HeadCalc probeert eerst de bestaande oplosroute. Na werkelijk falen krijgt
alleen een solve-entry drukhoogte binnen sqrt(machine-epsilon) cm aan de
verzadigde kant één gedempte herpoging. De complete lokale begintoestand wordt
daarvoor gekopieerd en hersteld. De eerste negatieve proefwaarde wordt kubisch
gedempt; de oorspronkelijke residu-, waterbalans-, pond- en convergentiecontroles
blijven beslissen. Elke fase houdt dezelfde iteratiegrenzen; maximaal kan de
lokale Newton-inspanning verdubbelen. Werkcounters tellen beide fasen.

Een eerdere algemene demping en een variant zonder oorspronkelijke-eerst-route
veroorzaakten nieuwe vastlopers op dag 35/36. Die varianten zijn afgewezen en
hun uitvoer blijft bewaard. De geselecteerde aanvulling verandert alleen
`src/legacy/b1_10_port/headcalc.f90` bovenop de bestaande PR-reparatie.

## Uitkomst

De echte 97 dagen met 908 mm neerslag voltooien bij 1e-6, 1e-4, 1e-3, 1e-2, 0.1 en 1 cm.
De strenge 1e-6-proef gebruikt 248.69 s CPU en geeft
34.62195021 mm afstroming. Een eenmalige tijdmeting is geen
algemene snelheidsclaim. Dit blijft de illustratieve kolom van 30 cm met vier cellen.

Ten opzichte van de eindige 1e-6-verfijning geeft 1e-3:

- Totale afstroming: -0.04767026 mm.
- Totale onderafvoer: +0.03174934 mm.
- Grootste dagelijkse opslagverschil: 0.04246515 mm.
- Transpiratie, gewasbiomassa en LAI: exact gelijk in deze proef.

De grootste onafhankelijke dagelijkse balansafwijking is over alle zes proeven
kleiner dan 4e-13 mm. De harde transactiemassagrens blijft 1e-14 cm. De eindige
verfijning is geen exacte fysische waarheid of ruimtelijke convergentietoets.

O0 met runtimecontroles en O2 geven bij 1e-3 exact dezelfde volledige fysieke
uitvoer en werkcounters. Actieve reconstructie na de natte dag 35 is eveneens
exact. Geforceerde afwijzing na één private stap behoudt 21 toestandsbits,
gewasrevisie en ontbrekende oppervlaktefluxbewijzen. De exacte dag 43-reproducer
slaagt bij O0/O2; een geforceerd falen van beide lokale Newton-fasen behoudt de
begintoestand. Per optimalisatie slagen 6 oorspronkelijke weerprofielen, de
onveranderde retry-test, constitutieve/bovenrandafgeleiden en 2 bestaande
solvercontracten. De volledige strenge 97 dagen zijn op O2 uitgevoerd.

## Bewijs en resterende integratie

Machineleesbaar resultaat: `PERF01_WET4_REVIEW_20261022_SUMMARY.json`.
Het nieuwe archief bewaart geslaagde, mislukte en verkeerd geforceerde
waarnemingen, trace, exacte bronbestanden en build-/uitvoeridentiteiten.
Controle: `python benchmarks/performance/verify_perf01_wet4_review.py --self-test`.

De oorspronkelijke bevroren broncontrole bij de oude HeadCalc geldt als
historisch bewijs; zij krijgt geen onterecht PASS op deze gewijzigde bron.
Canonical-toelatingscontroles moeten voor de gedeelde wijzigingen nog worden
verzoend. RossFast, hoogste low-air en brede F-CI zijn niet geselecteerd.
De automatische goedkeuringscontrole blokkeerde de publicatiepush wegens
ontbrekende expliciete toestemming om naar GitHub te publiceren. De aanvulling
is lokaal gecommit en klaar voor publicatie naar de bestaande PR.
