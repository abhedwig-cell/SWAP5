# FACTOR60 — twee minimumvoorraadtakken van domein3

Het afgeleidecontract is afgebakend en met de echte fluxprovider getoetst voor beide oorspronkelijke D2-minimumtakken. Met vaste positieve instroom geldt df=-(dL+f*dO)/O: op de voorraadstak dL0, op de volumetak de volledige GWL-/geometrieafgeleide dV. De totale uitpotentie O moet ook de kleine onverzadigde bijdrage bevatten. Geen Jacobiaanwijziging geïmplementeerd.

## Uitvoering

Baseline NODE59 4f9fee4229a8c7e4fd9b928e787c159af5a7517d; probepreregistratie a783e0c9b, linkherstel428e0b714. Alleen dezelfde twee verse D2 RESTART-routes. In poging2 zijn de echte actuele providers bij iteratie53 (W) en54 (V) onderzocht; drie headkolommen50/51/52, centrale perturbaties1e-7 en5e-8 cm, beide tekens. Dat zijn12 providerperturbaties per punt,24 per route. Geen extra trajecten of campagne.

| Route | Totale modeltijd inclusief probes | Uitkomst |
|---|---:|---|
|O0|6,903 s|normaal, ongecensureerd|
|O2|4,695 s|normaal, ongecensureerd|

Hard20s per route, bestaande interne16s/512commit/4retrygrenzen behouden. Fysica, klok, solver/backtracking, Jacobiaan, guards, dt/toleranties/reductie en budgetregels onveranderd. Alleen een observationele hook en een zelfstandige probe-subroutine zijn toegevoegd; alle overige bronnen ongewijzigd. De DTMIN58-objectclosure is hash-gecontroleerd geërfd; headcalc/probe herbouwd en gelinkt. Eerste linkpoging miste het nieuwe probe-object in de vooraf opgebouwde linklijst; foutlog bewaard en linklijst gecorrigeerd vóór enige modelrun. Er zijn exact twee modelroutes.

Alle26 herstelcontroles per route zijn succesvol: fysieke snapshot20.347.880 bytes, providercache3.247.712 bytes en IEEE-vlaggen exact hersteld. Begin-/eindpuntrecords zijn gelijk. O0/O2 hebben byte-identieke probe- en oorspronkelijke fysieke tekstuitvoer.44 oorspronkelijke tekstbestanden zijn geheel byte-identiek aan NODE59. Het bestaande inactieve-sorptie-observerbestand bevat daarnaast36 probe-observaties uitsluitend op de geselecteerde punten; alle oorspronkelijke regels blijven als exacte geordende subsequence behouden. Pogingen zijn gelijk na uitsluitend weglaten van rekentijd. Dit is loguitbreiding, geen veranderde oorspronkelijke trajectstaat.

## Gemeten afgeleiden

Domein3-W=0,03392523751972457 cm en I=9,992569961008096e-9 cm blijven in alle perturbaties constant.

| Punt | W-V [cm] | f | Minimumtak |
|---|---:|---:|---|
|iter53|-1,4890762358582554e-7|0,031222211877272477|W|
|iter54|+1,073727731726315e-9|0,034574537944803474|V|

De analytische GWL-keten met heads50/51 en de exacte VOLUNDR-gewichten sluiten op de centrale provider-FD. Het volledige112-componenten domein3-volumeprofiel verandert in geen van de geselecteerde perturbaties; de geometrieprofielbijdrage is hier dus0. Een algemene geometrie-invariant voor andere kolommen/toestanden volgt daar niet uit.

Indicatieve df/dh uit het contract, met analytische GWL-/geometrieketen en gemeten totale dO (eerste epsilon; eenheid1/cm):

| Minimumtak | head50 | head51 | head52 |
|---|---:|---:|---:|
|W|0|+0,0179198168|+0,0149650884|
|V|-11367,67135|-5380,53974|+0,0165706511|

De zeer grote GWL-kolommen op de volumetak verklaren waarom alleen lokale fluxafgeleiden bij de nabije minimumtakgrens onvoldoende zijn. Op de W-tak is de afgeleide niet algemeen0: ook daar verandert f met O. Dit is geen nulinstroomgeval.

## Kleine potentie, relevante afgeleide

Bij iter54 is de totale onverzadigde potentie slechts2,5397258272984656e-14 cm. Toch is dO_unsat/dH50 ongeveer -8,60618e-8 cm/cm en dO_unsat/dH51 ongeveer -4,07349e-8 cm/cm. De eerste is de gehele dO50, de tweede ongeveer18,15% van de totale dO51. Deze termen weglaten zou de afgeleide dus veranderen ondanks de kleine fluxwaarde.

De oorzaak is de oorspronkelijke contactweging: GWL ligt net onder de vaste macro-waterhoogte, met overlap2,40775293e-7 cm. In deze ondersteuning U50=B*overlap; zowel de GWL-contactterm als de lokale constitutieve afgeleide van B behoren tot dU. Op de W-tak is dit contact gesloten en blijft dat in alle perturbaties zo. Geen gewijzigde sorptieklok of nieuwe fysica.

Naast de factorbijdrage -P_i*df moet een volledige Jacobiaan ook -f*dP_i bevatten voor zover dit niet al correct lokaal aanwezig is. De echte productafgeleiden op zowel node52 als de contactcel50 zijn met de provider-FD gecontroleerd. Het contract sluit daarmee de factor- en potentieonderdelen uitdrukkelijk van elkaar af: een factor-rang-één-aanvulling alleen is nog geen volledig gekwalificeerde domein3-Jacobiaan.

## Afronding expliciet begrensd

De oorspronkelijke factorberekening gebruikt verschillen van bijna gelijke voorraden. Directe f-FD op zulke kleine headstappen bevat daardoor subtractieruis. Bijvoorbeeld op de W-tak/head51 geeft epsilon5e-8 ongeveer0,01808477 tegenover ketenwaarde0,01791982. De afwijking0,00016495 wordt geheel verklaard door de gemeten factorafronding gedeeld door de perturbatiestap.

De wiskundig identieke diagnostische volgorde ((W-L)+I)/O geeft een stabielere afgeleidentoets; de quotientketen met gemeten dL/dO sluit daarbij tot7,83e-11. De directe provider-FD en zijn afrondingsinterval blijven volledig bewaard. Dit is een analyse van meetnauwkeurigheid, geen wijziging van de fysische factor, tolerantie of acceptatiegrens. DERIVATIVE_AUDIT.csv en RESULT.json bevatten per tekenpaar de ruwe FD, keten, geometrie- en afrondingsintervallen en productchecks.

## Status en vervolg

Het oorspronkelijke model weigert onveranderd na60 dtmin-iteraties: Fmax2,2491570572547026e-5 op node52, som9,643422493501127e-5. Alleen schaalverzoek IDec1, FrRedu1; geen gereduceerde rekenstap, tijdvooruitgang, hostcommit of ledgerintegratie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS. Canonieke productie/Status-A onaangeraakt.

Gekwalificeerd: twee-takken-factorcontract voor de geselecteerde kolommen en vaste ondersteuning, actuele GWL-/geometrieketen, echte totale potentieafgeleide via centrale provider-FD, productregel en herstelneutraliteit met O0/O2. Niet gekwalificeerd: volledige analytische112-kolommenpotentiegradiënt, analytische implementatie van de constitutieve B-afgeleide, ties/clip-/supportgrenzen, correctie van een lineaire solve of convergentieherstel.

Het volgende gerichte werk is de volledige actuele potentiegradiënt (inclusief contact-/vochtafhankelijkheid in cel50) afbakenen of leveren voordat een volledige operator-Jacobiaan wordt geclaimd. Het factorcontract zelf is klaar voor een begrensde implementatie die die ontbrekende potentietermen niet verbergt. Guards blijven expliciet; geen vaste51- of nulinstroomguard versoepeld.

Herstel: DERIVATIVE_CONTRACT.md, STATUS/RESULT.json, DERIVATIVE_AUDIT.csv, PROBE_HOOK.patch, factor60_probe.f90, CODEX_FOLLOWUP.md en alle ruwe snapshot-/cache-/IEEE-/providerbewijzen. assess_factor60.py start geen model. EVIDENCE.json identificeert het streaming-gecontroleerde archief.
