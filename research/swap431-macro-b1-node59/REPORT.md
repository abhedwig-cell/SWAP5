# NODE59 â€” resterende node52-weigering na DTMIN58

De gerichte diagnose lokaliseert de afwijking van de Newtonlinearisatie op node52 tot de veranderende uitfactor van domein3. In alle87 echte lijnproeven na iteratie30 op dtmin verklaart de exacte productontleding van die factor de afwijking tussen de lokale Jacobiaanvoorspelling en de werkelijke operator, met hoogstens1,76e-10 cm/dag onverklaard verschil. De bestaande scalarvoorraadbegrenzing koppelt daarmee alle domein3-uitgaande fluxen aan de proefheads; de toegelaten Jacobiaancorrecties dekken deze toestand niet. Dit is sterker en specifieker bewijs dan alleen een algemene verdenking van domeinen2/3.

Het bewijst geen unieke globale stagnatieoorzaak, geen benodigde exacte analytische afgeleide op een minimumtakgrens en geen succesvolle toekomstige reparatie. Er is geen correctie geÃ¯mplementeerd.

## Routes en behoud

Baseline DTMIN58 823f4779187bdd0196a8062510967e7c2b0a5f0c; preregistratie8e853ebf5. Exact twee verse RESTART_D2-processen vanaf dezelfde eigen oorspronkelijke NATIVE55-checkpoint. De verzegelde DTMIN58-executables en alle Fortran-bronnen zijn hash-gecontroleerd en exact hergebruikt; geen hercompilatie, extra observer, providerprobe of alternatieve operatoraanroep.

O0 normaal in2,343 s; O2 normaal in1,640 s. Beide returncode0, ongecensureerd, onder hard20 s per route. Alle45 geselecteerde fysieke tekstbestanden per route zijn byte-identiek aan DTMIN58 en onderling O0/O2; pogingen zijn exact na weglaten van uitsluitend rekentijd. De volledige Newton-/proeflogging hoort bij die identiteit. Bestaande IEEE_DENORMAL-melding bewaard.

Fysica, sorptieklok, solver/backtracking, Jacobiaan/guards, toleranties, dt/reductie, interne16s/512commit/4retrygrenzen en budgetregels ongewijzigd. Geen nieuwe context, tuning of brede campagne. Canonieke productie en Status-A onaangeraakt.

## Werkelijke weigering en herstel

De eerste vervolgstep blijft de oorspronkelijke30-iteratieweigering. De retry op dtmin1e-5 doorloopt60 iteraties. Beste Fmax6,838039125461881e-6 bij iteratie53; eind-Fmax2,2491570572547026e-5 op node52, som9,643422493501127e-5. Lokale/totale grens1e-6/1e-5 blijven onvervuld. Op59 van de60 dtmin-iteratie-einden is node52 het globale maximum; eenmaal node57.

Er volgt het oorspronkelijke verzoek IDecMpRat1/FlDecMpRat. FrReduQ blijft1: geen gereduceerde stap uitgevoerd. De harness herstelt de proefstaat en stopt op NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED. Nul vervolg-hostcommits, geen tijdvooruitgang of ledgerintegratie. Finale nativecontext exact gelijk aan de begincontext behalve dt/dtold; ledger byte-identiek.

## Operator op de laatste proef

Residu-eenheid cm/dag. Node52 is verzadigd: opslagbijdrage0. De laatste operator is

`F52 = 0 + 0.00030994427797669937 - 0.35418339961537176 + 0.21778738951556167 + 0.13610855739240593`

`= 0.000022491570572547026`.

Bron- en wortelterm zijn0; de weergegeven termen zijn opslag, sink, bovenflux, onderflux en -macro-uitwisseling. De macroterm bevat netto domein1 -0,1313907606133318, domein2 -0,004966233069882399 en domein3 +0,0002484362908082663; domeinen4/5 zijn0. De grote eindwaarde van een domeinterm is op zichzelf geen bewijs dat dit domein de linearisatiefout domineert.

Alle3584 noderegels per route sluiten onafhankelijk: F uit operatorbijdragen, -macro uit vijf domeinnetten, en elk net uit uit-/instromen. Maximale afwijking2,78e-17. OPERATORS.csv bevat best53, na-best54, overshoot55 en eind60 voor nodes50/51/52/57.

## Voorraad en minimumtak

Op de60 echte dtmin-Jacobiaantoestanden geldt:

| Domein | Uitfactor | Minimumvoorraad | Instroom |
|---|---|---|---|
|1|1|L1,5 cm, onder W|positieve matrix-/andere instroom|
|2|0,24946244..0,25348234|alle60 L=W=0,12198513270212707 cm|positieve verdeelde matrixinstroom plus boveninstroom; nooit top-only|
|3|0,03121994..0,06504084|49maal L=W;11maal L=volume onder GWL|uitsluitend constante positieve boveninstroom|
|4/5|1|L0|positieve boveninstroom|

Voor domein3 is W=0,03392523751972457 cm. De169 echte dtmin-provider-evaluaties hebben alle een gedeeltelijke uitbegrenzing: f3 tussen0,031219938878494724 en0,9816709628227291. FrIn1; instroom I3 steeds9,992569961008096e-9 cm per stap; geen matrix-/interne instroom in domein3. De native GWL-cel blijft50; GWL ligt tussen -65,64259072498339 en -65,63458931591911 cm. Dit is geen hernieuwde celovergang rond -60 cm. De minimumtak is64maal W en105maal volume. De87 late proefparen omvatten55 Wâ†’volume,14 volumeâ†’W en18 Wâ†’W.

De oorspronkelijke stockidentiteit sluit: f3=(W+I-L)/O, met L=min(volume onder GWL,W), tot1,09e-11 in factor. O sluit als potentiÃ«le verzadigde plus onverzadigde uitstroming (maximaal2,64e-23 cm verschil). De onverzadigde potentie is klein maar niet overal0 (max7,20e-12 cm) en mag bij een later contract niet ongemerkt worden weggelaten. De oorspronkelijke drempel excess/dt>1e-7 en O>excess zijn op alle169 toestanden werkelijk actief.

Dit is een continue stukgewijze minimumbegrenzing met een takgrens; de eindige proefverschillen bewijzen geen nieuwe fysische sprong.

## Linearisatie en exacte productontleding

Uit de opgeslagen volledige112-componenten Newtonrichting en de lokale Jacobiaanrij volgt J D=F0 op node52 met maximaal2,09e-17 afwijking. De lineaire oplossing zelf is dus niet de bron van deze node52-afwijking. Voor iedere echte lijnproef is de voorspelling F_lin=F0-alpha J D bepaald, met de werkelijk uitgevoerde alpha uit DTMIN58. Er zijn geen fictieve residuals geÃ«valueerd.

Schrijf de werkelijke uitflux op node52 van domein3 als q3=P3*f3, met P3 de opgeslagen potentiÃ«le flux per dag. De exacte eindige productidentiteit luidt

`q3_1-q3_0 = f3_0*(P3_1-P3_0) + P3_1*(f3_1-f3_0)`.

De lokale afgeleide bevat de huidige gefactoriseerde flux/drukhoogtegradiÃ«nt en behandelt f3 daarbij als gegeven. De ontbrekende factorbijdrage aan F is in deze ontleding `-P3_1*(f3_1-f3_0)`. Domein3 heeft op node52 geen onverzadigde uit- of matrix-/interne instroom, zodat de vergelijking hier eenduidig is. De macro-waterhoogte van domein3 blijft op alle169 providers constant.

Over alle87 late proeven is de maximale werkelijke linearisatieafwijking0,007564703634205472 cm/dag. Na aftrek van uitsluitend de bovenstaande factorbijdrage resteert maximaal1,7588866856586317e-10. De overige macro-/matrixvariatie verklaart dus in deze opgeslagen richtingen vrijwel niets van de grote mismatch. Dit sluit de richtinggebonden diagnose op node52, zonder te stellen dat alle domein2-afgeleiden in andere richtingen volledig zijn.

## Waarom terugzoeken rond de beste staat blijft falen

Iteratie53 start op de W-tak met f3=0,0312222118773. De volle proef geeft f3=0,971604474945 en F52=-0,00748455034452. Proef2 met alpha1/3 landt net op de volumetak, W-V=1,073727731726315e-9 cm en f3=0,0345745379448: F52=-6,83803912546e-6. Dit is de beste iteratie-eindstaat, nog onvoldoende.

De volgende richting kruist in alle vier proeven terug naar de W-tak:

| Iteratie54 proef | alpha | f3 na proef | F52 | Werkelijk minus lineair voorspeld |
|---|---:|---:|---:|---:|
|1|1|0,031221397420|2,66815729463e-5|2,66815729463e-5|
|2|1/3|0,031220387636|2,213195431905e-05|2,66906470694e-5|
|3|1/9|0,031220051056|2,061541479997e-05|2,66936718004e-5|
|4|1/27|0,031219938878|2,01099015142e-5|2,66946799314e-5|

De D3-factorbijdrage verklaart iedere regel tot maximaal5,87e-12. Alle toegestane proeven overschrijden de nabije minimumtakgrens. De lokale linearisatie verwacht daarbij niet de factorverandering. Terugzoeken werkt nu werkelijk, maar vier verkleiningen brengen deze richting niet terug binnen de goede linearisatieregio. De oorspronkelijke uitputtingsregel neemt de laatste proef mee. Iteratie55 overschiet opnieuw; iteratie60 eindigt weer op de W-tak met te groot residu. Geen grotere zoeklus, extra iteraties of dt onder dtmin geprobeerd.

De tabel is afgeleid van bestaande echte proeven, niet van een nieuwe gevoeligheidscampagne. DIRECTIONAL_OPERATOR.csv bevat de volledige waarden en ontleding van alle254 proeven per route.

## Guardcontract en volgende afbakening

Alle90 actuele providers zijn geldig; JAC37 weigert correct met -3: werkelijke zonetuple50/50/-1, in plaats van zijn vaste51/51/51. Ook zijn verdere h51-/PeGWL-aannamen en top-only-instroomaanname voor domein2 gelden niet. JAC24 blijft inactief omdat zijn nulinstroomvoorwaarde de positieve I3 uitsluit; bovendien vereist hij uitsluitend de volumetak. Alleen een guard loszetten of index omzetten is dus geen geldige correctie.

De bron en richtingontleding rechtvaardigen nu een specifiek volgende contractvraag: een consistente niet-lokale domein3-uitfactorafgeleide bij constante positieve instroom, beide minimumtakken en de werkelijke GWL-/geometrieketen in cel50. Binnen Ã©Ã©n actieve tak is, met vaste W en constante I, `df=(-dL-f*dO)/O`, en `dq_i=f*dP_i+P_i*df`. Op de W-tak is dL0; op de volumetak moet dL via de echte GWL en eventuele geometrieafhankelijkheid worden vastgesteld. O bevat alle werkelijke uitpotenties, inclusief de kleine onverzadigde bijdrage. Tie-, support-, drempel-, nul-/vrijfactor- en providerstempelgevallen moeten expliciet begrensd worden voordat een implementatie geldig is.

Hier is uitsluitend diagnose gekwalificeerd voor de werkelijk gevolgde Newtonrichtingen en O0/O2. Geen analytische/finite-difference-afgeleidentoets, nieuwe Jacobiaan, geaccepteerde vervolgstep, volledige balansperiode, algemene herstart of promotie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS.

Herstel: STATUS.json, RESULT.json, CONTRACT.md, DIRECTIONAL_OPERATOR.csv, STOCK_LIMITS.csv, OPERATORS.csv, ITERATION_PROGRESS.csv en CODEX_FOLLOWUP.md. assess_node59.py doet0modelaanroepen. Een eerste postprocessingassertie gebruikte D1-instroomkolommen in plaats van D3; die indexfout is gecorrigeerd en gedocumenteerd in ANALYSIS_CORRECTION.json. Ruwe routes zijn niet veranderd of herhaald. EVIDENCE.json bindt bron, ruwe routes en uitvoer aan een streaming-gecontroleerd archief.
