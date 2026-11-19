# COMBINED62 — domein3-factor en potentie zonder dubbeltelling

Het gecombineerde contract is afgebakend en getoetst: voeg precies J3_full-J3_local toe, niet de volledige domein3-afgeleide bovenop de bestaande lokale bijdrage. De verzadigde diagonalen blijven eenmaal aanwezig. Netto resteert een factor-rang-één-term plus, bij open contact, de ontbrekende contact-/vochtpotentierij van cel50. De aanvulling is nog niet in de lineaire solve geïnstalleerd.

## Uitvoering en neutrale observatie

Baseline POTENTIAL61 a9eff47cd9928dad064b14ffbe09a950b4d101c9; preregistratie4d32d8a22. Twee verse originele D2 RESTART-routes O0/O2, dezelfde punten2/53 en2/54 en dezelfde48 echte providerperturbaties per route als POTENTIAL61. Geen nieuwe contexten of bredere campagne.

| Route | Totale modeltijd inclusief probes | Uitkomst |
|---|---:|---|
|O0|11,457 s|normaal, ongecensureerd|
|O2|8,359 s|normaal, ongecensureerd|

Hard20 s per route, originele interne16s/512commit/4retrygrenzen behouden. Enige nieuwe source is een observer van de actuele D3-increments rond ABSORPTION(2)/SATFLOW(4); alle overige Fortran-bronnen en bestaande proefhook/probe zijn exact gelijk aan POTENTIAL61. Alleen macrorate.o herbouwd en gelinkt op de geverifieerde POTENTIAL61-closure. Geen physics/clock/solver/Jacobianentry/guard/backtracking/tolerance/dt/reduction/budgetwijziging. IEEE_DENORMAL-melding bewaard.

Alle51 bestaande niet-timing-tekstbestanden per route zijn byte-identiek aan POTENTIAL61 en onderling O0/O2, inclusief alle eerdere providerprobes en herstelreceipts. De nieuwe lokale ownerlogs zijn onderling eveneens byte-identiek. Pogingen zijn gelijk na uitsluitend weglaten van rekentijd. Per route50 fysieke/cache-/IEEE-herstelcontroles slagen; geen nieuwe modelroutes voor de analyse.

## Lokale ownership echt gemeten

De observer neemt het verschil in dFdhMp vóór/na de echte domein3-call, afzonderlijk voor verzadigde en onverzadigde termen. De totale dFdhMp is bovendien exact gelijk aan de bestaande headcalc-registratie. Zo wordt geen bijdrage van andere domeinen afgetrokken.

De huidige D3-onverzadigde lokale afgeleide is0. De zeven verzadigde diagonalen51..57 zijn al aanwezig en sluiten op -f*dP_diag tot6,40e-18. Bij de gedeeltelijke contacttoestand kan de volledige D3-bijdrage daarom niet simpelweg bovenop deze diagonalen worden opgeteld.

Een algebraïsche negatieve controle meet precies die fout: de naïeve volledige optelling zou op punt53 maximaal0,0005735180583395783 per dag aan diagonaal dubbeltellen; op punt54 maximaal0,0006350966404313624. Dit is een matrixcontrole, geen extra counterfactual modelroute.

## Netto aanvulling

In residuteken is J3_full=-f*dP-P*(df)^T. De twee-buitenproductvorm van de netto aanvulling is

`DeltaJ3=(-P)*(df)^T + e50*w^T`,

waar w de ontbrekende residugradiënt van de cel50-potentie na aftrek van zijn werkelijk aanwezige lokale term is. Op W/contactgesloten53 is w0: rang hoogstens1. Op V/contactopen54 zijn contact en vocht aanwezig: rang hoogstens2. De numerieke split sluit tot6,37e-18; bestaande plus netto correctie reconstrueert de volle D3-afgeleide binnen afronding.

Voor punt54 zijn de twee niet-nul w-elementen:

- w50=0,00029755484897686586 per dag;
- w51=0,00014083896294584888 per dag.

De totale correctierij50 bevat daarnaast de factorbijdrage van de kleine onverzadigde P50 en is dus niet beperkt tot deze twee kolommen. Bijvoorbeeld DeltaJ50,50=0,00032642561749313565 en DeltaJ50,52=-4,208491049103198e-11. Alle kleine termen blijven bewaard.

De factorbijdrage op node52 is op punt54 sterk niet-lokaal: DeltaJ52,50≈+90,459991932898 en DeltaJ52,51≈+42,8164719657243 per dag. Dit zijn afgeleiden binnen de actuele volumetak, geen geaccepteerde nieuwe richting of bewijs van betere conditionering.

## Product- en massderivativechecks

Voor de hele D3-uitoperator geldt som_i J3_full(i,j)=L_j/dt, omdat W/I/dt vast zijn. Op de W-tak is die som0; op de V-tak de echte dV/dt. De onafhankelijke toets sluit tot2,49e-19 op53 en5,69e-14 op54. De nieuwe correctie verandert die relatie niet door de oude diagonalen dubbel te laten staan.

De gecomponeerde afgeleide is op alle actieve kolommen en alle112 uitvoerrijen vergeleken met de echte D3-netflux-FD. Netfluxinvoer in domein3 is hier0, zodat residuteken -dq eenduidig is.

| Punt | Maximale ruwe FD-afwijking [1/dag] | Maximaal gepropageerd diagnostisch interval |
|---|---:|---:|
|53/W|1,3125186067901382e-6|1,3125370821837062e-6|
|54/V|9,657987320110806e-6|1,2135237431379389e-5|

Alle afzonderlijke rij-/kolomchecks vallen binnen hun eigen gepropageerde interval. Deze intervallen bevatten de reeds vastgestelde subtractieafronding van de oorspronkelijke f, de GWL-/minimumvoorraadketen en potentie-FD-afronding/eindige-stapgemiddelden. De ruwe FD wordt niet vervangen door een gefingeerde nauwkeurige provider. De volledige numerieke matrixsplit zelf sluit veel scherper dan deze FD-meetnauwkeurigheid. Geen massatolerantie of fysisch acceptatiecriterium is verruimd.

## Grenzen en vervolg

COMBINED_CONTRACT.md specificeert de ownership, tekens/units, factor-/potentiegradiënt, actuele payload/stamps, afwijzing van overlappende correcties, alle geërfde support-/cap-/event-/minimum-/contact-/geometryguards en de matrixvoorwaarde zonder dubbeltelling. De diagnostische sample46 en ownerlog mogen niet zonder nieuw numeriek payload-/restorecontract in een latere corrector worden gebruikt. De oude JAC24/37-guards zijn niet versoepeld en hun niet-lokale correcties zijn op beide punten inactief.

Gekwalificeerd: conditionele gecombineerde D3-matrixaanvulling op deze twee oorspronkelijke providerpunten, alle acht actieve kolommen plus controle49, geen dubbeltelling, algebraïsche product- en D3-waterbalansafgeleide, werkelijke provider-FD binnen gemeten precisie, O0/O2 en neutrale observatie/herstel. Geen112-onafhankelijke-kolommen-FD of algemeen toestandscontract.

Niet gekwalificeerd: gebruik in de lineaire solve, nieuwe richting, conditionering/fallback, daadwerkelijke convergentie, nieuwe rollback/directretry/hostcommitwaterbalans, volledige periode of algemene native herstart. De solver weigert onveranderd op dtmin met Fmax2,2491570572547026e-5 op node52, som9,643422493501127e-5. Alleen IDec1-verzoek, FrRedu1; geen uitgevoerde fluxreductie, hostcommit, tijdvooruitgang of ledgerintegratie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; canonieke productie/Status-A onaangeraakt.

Volgende minimale fase kan het afgebakende D3-payload-/guardcontract implementeren en deze twee buitenproducten daadwerkelijk in dezelfde oorspronkelijke D2-vervolgsolve kwalificeren, zonder andere fysica of numeriek beleid te wijzigen. Het huidige rapport voorspelt niet dat dit convergeert.

Herstel: STATUS/RESULT.json, COMBINED_CONTRACT.md, LOCAL_OWNER_OBSERVER.patch, LOCAL_OWNERSHIP.csv, COMBINED_MATRIX.csv, COMBINED_FD_AUDIT.csv, CODEX_FOLLOWUP.md en ruwe uitvoer. assess_combined62.py start0modellen; EVIDENCE.json identificeert het streaming-gecontroleerde archief.
