# DIAG56 — gekoppelde weigering na NATIVE55

Gerichte diagnose voltooid op dezelfde oorspronkelijke D2-vervolgcontext. Beide herhalingen reproduceren NATIVE55 exact in 25 geselecteerde fysieke/solver/providerbestanden en in de pogingregistratie na weglaten van uitsluitend de rekentijd. O0 en O2 zijn onderling eveneens exact. Er is geen aanwijzing voor een nieuwe fout in de native installatie: de reeds gekwalificeerde continue route weigert dezelfde vervolgstep. Er is geen convergentieherstel geïmplementeerd of bewezen.

## Uitvoering en grenzen

Baseline: NATIVE55 `96f965ada561a99305413071faa914aa9d8eefd1`; preregistratie `b9d736aa1`. Alleen twee verse RESTART_D2-processen, met dezelfde eigen V6 phase1-checkpoint (`59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e`), originele invoer en exact hergebruikte verzegelde O0/O2-executables. Geen nieuwe build: Fortran-bronnen zijn byte-identiek en de binaire hashes zijn gecontroleerd tegen de NATIVE55-archive en identiteiten.

O0: 3,144 s; O2: 2,944 s. Beide normale, ongecensureerde afloop (returncode0), onder hard20 s per route. Interne16 s, bestaande commit-/retryposten, fysica, klok, solver, Jacobiaan, toleranties, dt-beleid en reductieregels ongewijzigd. Bestaande IEEE_DENORMAL-melding bewaard. Geen extra contexten, probes, parameterstudie of brede campagne. De kalenderlaadperiode is geen nieuw doorlopen modeltraject.

## Weigering en verzoek

Tijd blijft `35797.290431125148`. Residu-eenheid cm/dag; tijdstap in dagen.

| Poging | dt | Iteraties | Beste Fmax na iteratie | Eind-Fmax / node | Eind-som F | Werkelijke vector-evaluaties |
|---|---:|---:|---:|---:|---:|---:|
|1|2,0951312035156963e-5|30|1,1252294679932884e-3 (iter9)|2,1218091917013238e-3 / 52|8,637543343477884e-3|87|
|2, dtmin|1e-5|60|1,6603248028879136e-5 (iter8)|2,16137288712559e-4 / 57|1,5179109854425075e-3|142|

Lokale grens `CritDevBalCp=1e-6`; totale grens `CritDevBalTot=1e-5`. Zelfs de beste iteratie voldoet niet lokaal. Geen voorlopige convergentie/fresh acceptance. Poging1 loopt alle30 iteraties af en vraagt dt-verkleining. TimeControl begrenst de retry op dtmin. De oorspronkelijke solver verdubbelt daar MAXIT30 tot60. Na uitputting vraagt de macrotak `IDecMpRat=1`, `FlDecMpRat=true`. `FrReduQ` blijft1: er is alleen een verzoek, geen uitgevoerde of geaccepteerde gereduceerde stap. De harness stopt op `NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED` en herstelt de proefstaat. Nul vervolg-hostcommits, geen tijdvooruitgang of ledgerintegratie; finale native context verschilt alleen in dt/dtold. Dit is geen timeout.

## Aantoonbaar ineffectief terugzoeken op dtmin

Poging1 heeft86 echte lijnproeven, zes uitputtingen van vier proeven en zes verslechterde iteratie-einden. Op dtmin zijn er141 lijnproeven en vijftien uitputtingen/verslechteringen. De registratie van itry5/factor1/81 bij uitputting is een teller ná de lus, geen vijfde proef.

De tweede helft op dtmin (`numbit>MaxIt`) gebruikt `h=hold-difh*factmax1`, met een afzonderlijke relatieve stapbegrenzing. Deze bronregel gebruikt `factor` niet, hoewel dezelfde terugzoeklus die factor door3 deelt. In iteraties31,34,37,40,43,46,49,52,55,58 worden alle vier proefstaten (geregistreerde h-band, residu, som en objective) exact identiek. De gewone factor1,1/3,1/9,1/27 is daar dus uitsluitend een nominale lusregistratie, geen effectieve extra demping. Er zijn30 extra vector-evaluaties die door dat terugzoeken dezelfde staat herhalen.

Dit gedrag staat al in de oorspronkelijke geaudite headcalc, SHA256 `db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5`, overeenkomstig STATE02-identiteit. Het is niet door NATIVE55 toegevoegd. De eerste30 dtmin-iteraties bereiken best1,6603e-5, de laatste30 niet beter dan1,8723e-4. De bron en sporen bewijzen de ineffectieve backtracking in die tweede helft; ze bewijzen niet dat dit de enige oorzaak van de weigering is of dat één aanpassing voldoende is. Na uitputting neemt de bestaande lus de laatste niet-verbeterde proef mee naar de volgende iteratie. Geen numeriek beleid gewijzigd.

## Operator en voorraadkoppeling

Alle3206 gelogde noderegels per route sluiten onafhankelijk: F is de som van opslag, sink, -source, root, boven-/onderflux en -macro-uitwisseling. Per domein sluit net=unsatout+satout-matrixin-internalin. Maximale rekenafwijking2,78e-17.

Het globale maximum ligt op alle90 iteratie-einden in de gelogde band44..57: poging1 steeds node52; poging2 49maal52 en11maal57. Verzadigde nodes51..57 hebben op de laatste evaluatie nul matrixopslagbijdrage; grote verticale fluxen en macro-uitwisseling moeten elkaar dus nauwkeurig opheffen.

| Eindtoestand | opslag | sink | bovenflux | onderflux | -macro | F |
|---|---:|---:|---:|---:|---:|---:|
|poging1 node52|0|0,0003099443|-0,3510626474|0,2158789477|0,1369955646|0,0021218092|
|dtmin node57|0|0,0001929434|-0,0569629744|0,0421520181|0,0148341502|0,0002161373|

De macroterm is niet uitsluitend domein3: eind node52/poging1 heeft netto domeinen1,2,3 respectievelijk -0,1320999894, -0,0051435403, +0,0002479651. Eind node57/dtmin respectievelijk -0,0174505531, +0,0026082553, +0,0000081476. Alle volledige componenten staan in FINAL_OPERATORS.csv.

De90 echte Jacobiaantoestanden tonen:

- Domein2: alle90 gedeeltelijk begrensd; uitfactor ongeveer0,247..0,279. Minimum L is steeds W. Positieve instroom komt behalve van boven vooral vanuit de matrix; het top-only-contract geldt op geen enkele toestand.
- Domein3: positieve topinstroom, constant binnen elke poging (bedragen2,0935745128621683e-8 en9,992569961008096e-9 cm). Uitfactor poging1 ongeveer0,0314..1 (27partieel/3vrij), dtmin0,0312..0,9811 (60partieel). L=W op23/30 en45/60 toestanden; L=volume onder GWL op7/30 en15/60. Dit is een werkelijke wissel van de minimumtak binnen dezelfde GWL-cel. Kleine niet-nul potentiële onverzadigde uitstroom komt eveneens voor; niet stilzwijgend als nul behandelen.
- Domeinen1,4,5 houden uitfactor1. De voorraad-/factoridentiteit voor de gedeeltelijke takken is numeriek gecontroleerd in RESULT.json.

Bij FrIn1 en actieve uitbegrenzing geldt, onder de bestaande drempelbeslissingen, `f=(W+I-L)/O`. Voor een afgeleide binnen één tak is daarom `df=(dI-dL-f*dO)/O`, met W de vaste beginvoorraad. Voor domein2 met L=W is dL0, maar dI niet op voorhand0. Voor domein3 verschilt dL tussen de voorraad- en geometrische tak. Dit begrenst de benodigde analyse; het is geen geïmplementeerde of numeriek afgeleidengetoetste Jacobiaan. Ook de instroom in domein1 en de lokale fluxafgeleiden blijven onderdeel van de echte gekoppelde operator.

## Waarom bestaande correcties niet actief zijn

Alle90 actuele providers zijn geldig; JAC37 registreert steeds guard -3. De werkelijke zonetuple is50/50/-1 in plaats van51/51/51. Daarnaast h51>1 en PeGWL999, zodat ook de verdere vaste h51/PeGWL-aannamen niet gelden. Alleen de celindex omzetten of de eerste guard versoepelen zou het contract onterecht uitbreiden. De later getoetste top-only-instroomaanname voor domein2 faalt eveneens.

JAC24 is alle90 keren inactief: de oorspronkelijke nulinstroomguard sluit de positieve instroom in domein3 al uit. Daarnaast varieert de minimumtak en is onverzadigde potentiële uitstroom soms niet nul. Geen bewijs voor een ontbrekende cache of verkeerd herstelde provider.

Alle229 echte provider-evaluaties houden native GWL-cel50. GWL ligt voor poging1 tussen -65,6474914553 en -65,6183077527 cm en voor dtmin tussen -65,6425907031 en -65,6187317692 cm. Dit is geen herhaling van de eerder herstelde celovergang rond -60 cm. Het minimumtakwisselen en de ontbrekende toegelaten niet-lokale afgeleiden zijn gerichte kandidaten voor de stagnatie, geen bewezen unieke oorzaak.

## Betekenis en vervolg

Diagnose gekwalificeerd voor deze D2-vervolgstap en O0/O2; geen solverherstel, geaccepteerde vervolgstep, volledige periodebalans, algemene herstart of promotie. B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. Canonieke productie en Status-A ongewijzigd.

Eerst veilig vervolg: het numerieke contract van de dtmin-tak afbakenen (relatieve stapbegrenzing plus effectieve backtracking), inclusief vergelijking met de oorspronkelijke bedoeling, op dezelfde opgeslagen context. Niet meteen een guard loszetten of een Jacobiaan uitbreiden. Afzonderlijk blijft voor een eventuele latere Jacobiaan-aanvulling een contract nodig dat de werkelijke cel50, verdeelde positieve instroom, beide minimumtakken en geldende drempel-/supportbeslissingen omvat. Deze unit verandert geen van beide contracten.

Herstelpunten: CONTRACT.md, BINARY_REUSE.json, assess_diag56.py, RESULT.json, ITERATION_PROGRESS.csv, STOCK_LIMITS.csv, FINAL_OPERATORS.csv, ORIGINAL_NUMERICAL_BRANCH.txt en de onveranderde bron- en ruwe uitvoersnapshots. EVIDENCE.json identificeert het streaming-verzegelde archief; eerdere continue/native equivalentie is geërfd uit NATIVE55, niet opnieuw als extra route uitgevoerd.
