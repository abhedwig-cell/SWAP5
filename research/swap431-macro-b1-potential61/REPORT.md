# POTENTIAL61 — potentiegradiënt inclusief contact en vocht

De volledige conditionele domein3-potentiegradiënt is afgebakend en getoetst op beide oorspronkelijke D2-punten. Binnen de actuele vaste-coëfficiënten-/geometrie-/ondersteuningscontext bestaat hij uit zeven verzadigde diagonalen voor51..57 en, bij open contact, twee elementen in rij50 via heads50/51. De lokale vochtketen is expliciet opgenomen. Er is geen gradiënt geïnstalleerd in de solver-Jacobiaan.

## Routes en grenzen

Baseline FACTOR60 34028ce9d9154243a072f5066c41fa628ddaa02d; preregistratie fba881cd4. Alleen twee verse originele D2 RESTART-routes O0/O2. Per oorspronkelijk punt53/54 zijn alle actieve headkolommen50..57 en buitencontrole49 onderzocht: centrale1e-7 cm voor49..57; aanvullend5e-8 voor50/51/52.24 providerperturbaties per punt,48 per route. Geen andere context of brede campagne.

| Route | Modeltijd inclusief probes | Uitkomst |
|---|---:|---|
|O0|6,550 s|normaal, ongecensureerd|
|O2|5,886 s|normaal, ongecensureerd|

Hard20 s per route en oorspronkelijke interne16s/512commit/4retrygrenzen behouden. Fysica, klok, solver/backtracking, Jacobiaan/guards, toleranties, dt, reductie en budgetregels onveranderd. Alleen de bestaande probehook is naar de uitgebreide zelfstandige probe geleid. Herbouw headcalc/probe op hash-gecontroleerde DTMIN58-objectclosure; geen fysische implementatie gewijzigd. IEEE_DENORMAL-melding bewaard.

## Resultaten

De echte provider heeft op beide punten sat-uitondersteuning51..57. In53 is het cel50-contact gesloten; in54 gedeeltelijk open, met sorptiviteit als echte winnaar en startklok0. De ongecontacteerde sorptiehoeveelheid is ongeveer3,770714119484479e-8 cm, ruim onder de oorspronkelijke piekcap0,02 cm. De lokale vochtdeficit is3,776710300496866e-7, boven de originele1e-8-takgrens.

De analytische potentiekolommen zijn tegen ALLE112 uitvoerrijen vergeleken, inclusief totale dO.

| Punt | Contact | Maximale potentiegradiëntafwijking [cm/cm head] |
|---|---|---:|
|iter53, W|gesloten|5,410073549496101e-16|
|iter54, V|gedeeltelijk|1,0217214819630055e-14|

Alle actieve headkolommen zijn getoetst, niet alle112 onafhankelijke heads. De overige matrixelementen zijn structureel0 binnen het expliciete vaste-ondersteuningscontract. Cel49 levert daadwerkelijk een nulkolom. Het volledige Vol3-/CDarcy-profiel en macro-waterhoogte blijven in alle geselecteerde perturbaties exact gelijk; materiaal-/wet-/geometrieveranderingen worden niet stilzwijgend genegeerd.

## Vocht en contact afzonderlijk

Voor het gedeeltelijke contact op iter54 geldt U50=B*overlap, B=1,0548115819399513e-7 en overlap ongeveer2,40775e-7 cm. Met de officiële moiscap is B'_50=-1,229148542229283e-7. De onbegrensde sorptiviteit volgt de oorspronkelijke macht van de vochtdeficit; zijn keten via theta is analytisch opgenomen.

| Bijdrage aan dU50/dH50 [cm/cm] | Waarde |
|---|---:|
|lokale vochtketen overlap*B'|-2,959486179081112e-14|
|GWL-contactterm -B*G_50|-8,606181437016742e-8|
|som|-8,606184396502921e-8|

De head51-kolom bevat alleen de GWL-contactterm, ongeveer -4,07348792833302e-8. De kleine vochtterm wordt behouden en is niet naar0 afgerond. De volledige hoeveelheidgradiënt wordt door dt gedeeld voor rate-afgeleiden.

De vochtterm is onafhankelijk onderzocht via de ongecontacteerde echte sorptiviteit: dB/dtheta≈-0,1655252553, relatieve FD-afwijking maximaal1,79e-9. Rechtstreeks dtheta/dH uit zeer kleine headverschillen bevat aftrekafronding bij theta≈0,444; die meetnauwkeurigheid verklaart de circa0,02% variatie van ruwe dB/dH-FD. De officiële moiscap en de gepropageerde theta-afrondingsgrens zijn bewaard. Geen solver- of fysische tolerantie aangepast.

## Betekenis voor een latere correctie

POTENTIAL_CONTRACT.md geeft de exacte verzadigde diagonaal, de sorptiviteits-/contact-/vochtformule, units en guards. De nieuwe potentiegradiënt kan met FACTOR60 worden gecombineerd tot dq=f*dP+P*df. Daarbij moeten reeds aanwezige lokale termen expliciet worden afgetrokken; met name de bestaande kleine-fluxderivatiegrens maakt de cel50-potentieafgeleide niet automatisch aanwezig. Factor-rang-één en ontbrekende cel50-potentierij blijven afzonderlijk herkenbaar.

De afbakening is voor deze huidige SwAbs1/startklok/sorptiviteitswinnaar/ongecapte/contacttak en vaste profielen. Niet getoetst zijn SwAbs2, Darcy-winnaar/max-ties, piekcap, eventwissels, veranderende geometrie/materialen, exacte contact-/minimumties of andere ondersteuning. De nieuwe payload zou actuele stamps en transactioneel herstel nodig hebben. De oude sample46-getter is alleen diagnostisch en mag niet zonder dat contract als numerieke afgeleidecache worden gebruikt.

## Herstel en ongewijzigde uitkomst

Per route50 fysieke snapshot-/providercache-/IEEE-restorecontroles slagen byte-exact. De bron-/probeoutputs zijn onderling O0/O2 exact.44 oorspronkelijke fysieke tekstbestanden zijn byte-identiek aan NODE59; inactieve-sorptie-observerregels nemen door de probes toe, maar alle oorspronkelijke regels blijven een exacte geordende subsequence. Pogingen zijn gelijk na weglaten van uitsluitend rekentijd.

Een eerste postprocessingassertie omvatte ook het niet-geserialiseerde diagnostische sample46-sequencenummer. Alleen dat nummer veranderde bij54 van204 naar205; fysica, cache en IEEE-staat zijn exact hersteld. De controle is tot die toegestane diagnostische afwijking beperkt en vastgelegd in ANALYSIS_NOTE.json. Geen modelroute herhaald.

De solver weigert onveranderd op dtmin na60 iteraties, met Fmax2,2491570572547026e-5 op node52. Alleen IDec1-schaalverzoek, FrRedu1, geen gereduceerde stap/hostcommit/tijdvooruitgang/ledgerintegratie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; canonieke productie/Status-A onaangeraakt.

Gekwalificeerd is nu de conditionele volledige domein3-potentiegradiënt binnen deze ondersteuning, inclusief alle actieve kolommen, contact- en vochtketen. Niet gekwalificeerd zijn een geïnstalleerde volledige gekoppelde Jacobiaan of convergentie. Een volgend minimaal correctiecontract kan de gevalideerde domein3-factor- en potentietermen combineren, met behoud van alle guard-, state-, budget- en fysicagrenzen.

Herstel: STATUS/RESULT.json, POTENTIAL_CONTRACT.md, GRADIENT_AUDIT.csv, SPARSE_POTENTIAL_GRADIENT.csv, PROBE_HOOK.patch, potential61_probe.f90, CODEX_FOLLOWUP.md en ruwe provider-/snapshot-/cache-/IEEE-uitvoer. assess_potential61.py start0modellen. EVIDENCE.json bindt alles aan het streaming-gecontroleerde archief.
