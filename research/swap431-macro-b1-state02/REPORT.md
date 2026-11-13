# SWAP431-MACRO-B1-STATE02

**Besluit: `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`.** V1 kan verder worden gekwalificeerd als verbetering van de bestaande, zo nodig gereduceerde numerieke benadering. V1 is op de elf gereduceerde stappen **geen** geconvergeerde oplossing van de ongereduceerde uitwisseling. Geen promotie naar B1.12, geen productiepatch, geen migratie.

## Basis, actuele ontwikkeling en bewijsherstel

Onderzoeksbasis: `research/swap431-macro-b1-accept01-798c0bff`, definitieve commit `87792cdee54380424b9e1efb62ac272cdde1ab76`; onderliggende audit `798c0bff798e6906c46b0cbfb8c8850fed3a037e`. Nieuwe geïsoleerde branch: `research/swap431-macro-b1-state02-20261113`. De live remote heads zijn vooraf gecontroleerd: geen STATE02-opvolger aanwezig. Canonical stond op `e157e65ff36305d8661f7c8afb9577bad6b6ecd0`; ACCEPT01/audit zijn daar niet geïntegreerd, en het B1-manifest is ongewijzigd B1.12. Canonical Status-A blijft de afzonderlijke macroporiënvrije release.

De ACCEPT01-capsule heeft SHA-256 `80c6adaf4228e9332fabcecbe3ec3582636c005d6081916e85135ec301f0cf71`. Alle 1.099 manifestleden zijn gecontroleerd; de oorspronkelijke beoordelaar reproduceert het opgeslagen `RESULT.json` exact, zonder compiler/model. Zie `RECOVERY.json`. Daarmee blijven de eerdere tweedaagse Linux-resultaten bruikbaar binnen hun bestaande grenzen; zij zijn niet opnieuw als campagne uitgevoerd.

## Vraag 1: procesgeheugen en werkelijke rollback

De bestaande eerste V1-afwijzing is op native Windows opnieuw bereikt vanuit de oorspronkelijke koude invoer, tot uitsluitend de geselecteerde context `t1900=35796.92`, `dt=0.002 d`. Twee onafhankelijke identieke prefixes vervangen de Linux-forks; vóór de splitsing zijn alle negentien gemeten veldgroepen bytegelijk. De native begincontext verschilt tegenover de bewaarde Linux-context uitsluitend door afronding: maximaal `8.71e-13 cm` in h, `1.67e-16` in theta; klok/eventflags zijn exact gelijk. Dit is een afzonderlijk compilerprofiel, geen claim op Linux-binaire gelijkheid.

Route A voert de echte grote afgewezen stap uit, `SoilWaterStateVar(2)`, `MacroStateVar(2)`, oorspronkelijke `TimeControl(5)`, en de kleine retry. Route B slaat alleen die grote trial over en voert dezelfde verkleining en kleine retry uit. Beide voeren vervolgens daadwerkelijk `SoilWater(3)` uit, dus inclusief `MACROSTATE`, de voorraadupdate en de daaropvolgende geaccepteerde sorptieklok. De diagnostische recursieve declaratie maakt uitsluitend die geneste observatieroute mogelijk.

| Controle | O0 en O2 |
| --- | --- |
| Echte afwijzing | `fldecdt=true`, `FlDecMpRat=false` |
| Kleine retry | `dt=0.0006666666666666666 d`, geaccepteerd |
| Verschillen direct na rollback | referentie-theta `0.444`, sorptiviteit `0.2842412382630967`, eventflag `1`, trialuitwisseling `0.09285524550525012` |
| Voorraden, volumes en klok na rollback | hersteld/gelijk aan directe route |
| Na kleine retry | alle negentien groepen bytegelijk |
| Na volledige geaccepteerde macro-overgang | alle negentien groepen bytegelijk |
| Grootste sorptieklok voor/na commit | `0.012999999989697244` / `0.01366666665636391 d` |

**Classificatie uit de oorspronkelijke bron:**

- `ABSORPTION` zet `FlEndSrpEvt(id,1:numnod)=true` vóór de taakselectie en berekent de actieve flags opnieuw. De afwijkende flags na afwijzing zijn in deze route trialresultaten, ook waar de oorspronkelijke klok positief is.
- `ThtSrpRefDmCp` en `SorpDmCp` zijn procesgeheugen zodra een sorptie-event loopt. Trialberekening schrijft ze alleen voor `Time<1e-8`; de eerdere negen gewijzigde referentiecellen hadden klok nul. De kleine retry herberekent deze startreferenties. Bij een positieve klok leest ABSORPTION de referentie, maar verandert haar niet. `MACROSTATE` actualiseert/reset de referentie en klok pas na acceptatie.
- Lokale SAVE-velden `DelHDmCp`, `Diffusivity`, `FlSorp` en de MACRORATE-ratewerkarrays dienen de huidige rate/afgeleide-evaluatie; SAVE alleen bewijst geen herstelplicht. `FrMpWalWet` en `FrMpWalWetOld` zijn in de geselecteerde trial niet schadelijk gewijzigd. De lokale kwadratuurhistorie in `MACROINTEGRAL` wordt pas op de geaccepteerde route gebruikt; deze proef kwalificeert geen algemene herstart daarvan.
- `MacroStateVar` bewaart slechts domeinbodems, volumes en onverzadigde compartimentvoorraden. Dat is geen volledige geheugensnapshot. De directe geheugenongelijkheid mag echter niet worden gelijkgesteld aan aangetoonde hydraulische schade.

**Antwoord:** binnen deze natte context is het resterende verschil veilig herberekend trialwerk; noodzakelijke ontbrekende rollback met doorwerkend gevolg is niet aangetoond. Dit is geen algemeen bewijs dat alle geheugenvelden overbodig zijn. De capsules bewaren geen onderscheidende oorspronkelijke begincontext van een droge/eventeindafwijzing met positieve klok. De eerste-droge koude initialisatie is hiervoor onvoldoende, en residu-/daguitvoer reconstrueert geen volledige SAVE-toestand. Daarom blijft juist die route open en stopt het zoeken volgens de stopregel. Geen nieuwe scenariofamilie en geen geheugenpatch.

## Vraag 2: de elf gereduceerde stappen

Alle elf bestaande ACCEPT01-tijden zijn opnieuw bereikt, voor beide optimalisaties. Iedere route stopt bij haar geselecteerde geaccepteerde stap; er is geen tweedaagse eindcampagne of 481-daagse berekening. De elf tijdsduren tellen op tot dezelfde `0.0014613540144521983 d` als ACCEPT01.

De V1-eindcontrole heeft op dat moment de actuele oorspronkelijke operator geëvalueerd met `IDecMpRat=1`, dus `FrReduQ=0.1`. De proef bewaart dat geaccepteerde residu en de domeinuitwisseling. Daarna evalueert zij **eenmalig en uitsluitend diagnostisch** `vector_F(1,hgrad)` met `IDecMpRat=0`, waarna het proces stopt. Er worden geen drukhoogten of fysische parameters aangepast, geen kleinere stap opgelost en geen ongereduceerde toestand geaccepteerd. De oorspronkelijke begingeschiedenis, positieve-klokreferenties en voorraad zijn behouden; nulklokreferenties en eventflags worden bij dezelfde h/theta volgens dezelfde oorspronkelijke regels berekend. De klok en verzadigde voorraad zijn expliciet vóór/na exact gelijk gemeten. Elke probe gebruikt een eigen oorspronkelijke prefix, zodat de tegenfeitelijke evaluatie nooit een volgende geselecteerde context beïnvloedt.

| Grootheid, alle elf contexten | Met gebruikte reductie | Zonder reductie |
| --- | --- | --- |
| Maximum lokaal residu, bereik | `4.24e-10` tot `3.08e-8` | `0.174252` tot `0.531231` |
| Absoluut totaal residu, bereik | `4.68e-10` tot `3.52e-8` | `0.477555` tot `1.097285` |
| Lokale grens | `1e-6`, 11/11 geslaagd | `1e-6`, 11/11 gefaald |
| Totale grens | `1e-5`, 11/11 geslaagd | `1e-5`, 11/11 gefaald |

De maximaal lokale verandering in uitwisseling ligt tussen `0.174252` en `0.531231 cm/d`. Het residuverschil wordt geheel door de uitwisseling verklaard: maximum van `abs(F_unred-F_red+q_unred-q_red)` is `2.09e-17`. h/theta blijven exact gelijk. De volledige elf regels staan in `RATE_COMPARISON.csv`; alle vectoren en beide compilerprofielen staan in `data/` en `RESULT.json`.

**Fysische betekenis en behoud:** MACRORATE gebruikt de gereduceerde domeinfluxen daadwerkelijk in `QExcMpMtx`; MACROSTATE gebruikt dezelfde domeinfluxen in de geaccepteerde voorraadupdate. De reductie is dus niet alleen een tijdelijke Newtonhulp. Op de eerste context is de berekende macrovoorraadverandering uit `dt*(Qin_lat+Qin_vert-Qexchange-Qrapid)` `-2.24166529906303e-5 cm` met reductie en diagnostisch `-2.24166529906303e-4 cm` zonder reductie. De overige contexten tonen dezelfde verandering van de voorraadterm. Dit zijn bij vaste drukhoogten berekende lokale verschillen, **geen** voorspellende ongereduceerde trajectfout of toegelaten voorraadcorrectie.

De koppeling blijft in alle 22 probes exact gepaard: `QExcMpMtx == sum(QExcMtxDmCp,dim=1)`. Het wijzigen van de geaccepteerde flux zonder matrixheroplossing zou de acceptatie ongeldig maken. Gereduceerde uitwisseling kan intern conservatief zijn en toch een andere oplossing vertegenwoordigen dan de ongereduceerde formulering. De oorspronkelijke MACROSTATE-voorraadbegrenzing blijft aanwezig; deze proef vervangt geen onafhankelijke volledige substep-inventariscontrole. De eerdere dagelijkse waterbalansen blijven geërfd bewijs op gedrukte precisie, geen nieuw algemeen behoudscertificaat.

**Antwoord:** V1 certificeert hier uitsluitend de gereduceerde numerieke benadering. De ongereduceerde evaluatie faalt op beide criteria in alle elf contexten. Dit toont op zichzelf geen fout in de oorspronkelijke reductiewet; die is ongewijzigd gebleven.

## Werkelijke code, uitvoering en grenzen

Uitsluitend twee experimentele Fortran-observatiekopieën zijn toegevoegd: `headcalc_probe.f90` en `soilwater_probe.f90`. V1's bestaande correctie blijft onveranderd; er is **geen aanvullende solver- of procesgeheugencorrectie**. B0-archief, B1.12, canonical, actieve werkbranches en releasebasis zijn niet gewijzigd. Publieke interfaces en fysische vergelijkingen zijn niet gewijzigd.

Volledige native closures zijn werkelijk gebouwd met GNU Fortran 16.2.0, MSYS2 UCRT64 Windows, O0/O2, oorspronkelijke platformselectie, `-finit-local-zero`, `-fallow-argument-mismatch`. Bouwlogs, bronhashes en executable-identiteiten zijn bewaard. `O*_RELINK.json` identificeert de definitief geteste observatiebronnen; `O*_IDENTITY.json` bewaart de eerdere buildidentiteit vóór vermindering van trace-I/O. De twee gewijzigde objecten zijn voor elk profiel opnieuw gebouwd en gekoppeld.

Drie eerste O2-routes met per-poging open/append/close-tracering bereikten de grens na `20.026–20.213 s`, vóór de geselecteerde context. Ze blijven gecensureerd bewijs in `censored-trace/`. Alleen die niet-essentiële tracering is vervolgens verwijderd; fysica, criteria, tijdgrenzen en geselecteerde meetuitvoer blijven gelijk. Zes geslaagde eerste selectieproeven blijven in `pilot-six/` en Git bewaard. De definitieve 26 routes (11 rateprobes + afwijzing/direct per O0/O2) slagen elk binnen `1.801 s`. Alle definitieve meetvectoren zijn bytegelijk O0/O2. Geen modelroute kreeg meer dan twintig seconden.

Dit betreft één geheugencontext en de elf reeds bekende gereduceerde contexten, geen derde solvervariant, nieuwe toestandarchitectuur of nieuw algemeen kwalificatieframework. Geen langere historische campagne, geen eigen herstartkwalificatie en geen derde fysische optie zijn uitgevoerd. De C-forkhelpers zijn hier niet gebruikt; de native prefixes bieden dezelfde gecontroleerde splitsing zonder Linux-runtime.

## Vraag 3 en kleinste vervolg

**V1 is geschikt voor verdere B1-kwalificatie met expliciete uitsluitingen**, mits de beoogde referentie de bestaande reductiebenadering uitdrukkelijk mag behouden. De naam “volledig gekoppelde acceptatie” moet dan aangeven welke reductie actief is; zij mag geen ongereduceerde fysische convergentie suggereren.

De kleinste volgende stap is eerst dat referentiecontract vastleggen. Bij behoud van reductie: één oorspronkelijke nat-naar-droog/eventeindcontext met positieve sorptieklok, echte afwijzing, herstel, acceptatie en eigen korte herstart kwalificeren; plus een onafhankelijke gekoppelde substep-voorraadinventaris voor de eerste reductiecontext. De benodigde droge context is nu niet volledig bewaard, dus geen bewijsclaim daarvoor.

Wanneer ongereduceerde convergentie verplicht is, is deze V1-route **niet gereed** voor dat doel. De concrete blokkade is acceptatie van een ander operatorprobleem zodra reductie actief wordt. De meest verdedigbare afzonderlijke onderzoeksroute is een begrensde proef op uitsluitend de eerste reeds geselecteerde toestand met heroplossen/afwijzen onder een expliciet ongereduceerd acceptatiecontract. De reductieregel wordt in deze ronde niet gewijzigd en die vervolgroute is niet gestart.

Er is geen PR naar canonical of de officiële referentielijn geopend. De onderzoeksbranch bewaart de concrete probes, ruwe vectors en het begrensde besluit; promotie vereist afzonderlijke kwalificatie.

Gegevenscontrole zonder modellen: `python research/swap431-macro-b1-state02/assess_state02.py`.
