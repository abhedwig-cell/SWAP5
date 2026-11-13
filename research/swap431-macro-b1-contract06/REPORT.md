# SWAP431-MACRO-B1-CONTRACT06

**Voor de onderzochte oorspronkelijke veldroute is de sprong een aantoonbare afwijking van het gedocumenteerde fysische contract. Eén minimale experimentele correctie wordt door de lokale proeven ondersteund.** De harde air-entry-test is bewust gecodeerd, maar sluit Darcy-instroom uit waar deze uitvoering de matrix nog onverzadigd behandelt en het gedocumenteerde drukgradiëntcontract positieve Darcy-instroom voorschrijft. De precieze historische bedoeling achter de GEM-aanpassing blijft onbekend; een broncommentaar alleen maakt de extra uitsluiting niet tot een onderbouwde fysische wet.

Met uitsluitend verwijdering van die extra uitsluiting convergeert de bestaande V1 op exact dezelfde levende begincontext **ongereduceerd in drie iteraties**. De oorspronkelijke sprong van circa `0.128 cm/d` wordt in het lokale drukhoogtepaar teruggebracht tot een gewone variatie van `2.394e-9 cm/d`. De onafhankelijke geaccepteerde waterinventaris sluit tot `3.506e-13 cm`.

Besluit: **`B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS` voor V1 plus deze ene contractherstelpatch.** De ongewijzigde V1 blijft voor de ongereduceerde eis niet gereed. De nieuwe combinatie is geen gekwalificeerde B1.12-opvolger en wordt niet gepromoveerd.

## Basis en brongezag

Basis: definitieve STAGNATION05-commit `81e00d043ce322a60f4377a93c56e64beed3f90a`. Nieuwe branch: `research/swap431-macro-b1-contract06-20261113`. De gebruiker vroeg expliciet het bedoelde contract vast te stellen en alleen bij aantoonbare fout een minimale correctie te rechtvaardigen. Geen opvolger van STAGNATION05 was remote aanwezig.

Canonical stond bij reconciliatie op `8d08011ffbdce693b8e1a8cd81b13d6c3d80896c`. De delta sinds `af65d5a26` betreft common-profile/RC1-platformkwalificatie. De toevoeging van optionele `extra_flags=()` aan `b0_source_runner.py` verandert de standaard niet. Deze ronde gebruikt de reeds geverifieerde opgeslagen source/objectclosures; zij herbouwt geen bron uit gewijzigde canonical en wijzigt canonical niet.

Gebruikte primaire autoriteiten:

- Kroes et al. (2017), **SWAP version 4**, WER-rapport 2780, gedrukte pp.100–101, vergelijkingen 6.32–6.35: [DOI/download](https://edepot.wur.nl/416321), [WUR-publicatierecord](https://research.wur.nl/en/publications/swap-version-4/).
- De actuele officiële [SWAP-handleiding, macroporiën, sectie 6.3.2](https://tmp.swap.alterra.nl/manual/06_macropore_flow.html#lateral-flow-into-the-unsaturated-soil-matrix), vergelijkingen 6.49–6.52, als aanvullende bevestiging van dezelfde proceskeuze.
- De onveranderde B0-bron: `ABSORPTION`, `CALCGWL`, `MOD_MvG`-initialisatie en `WATCON`, plus de oorspronkelijke Andelst-invoer. B0-source-archiefhash blijft `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

De historische handleiding is werkelijk via WUR opgehaald, tekstueel gelezen en op de twee relevante pagina's visueel gecontroleerd. PDF-SHA-256: `1cf1c350870fc7f7923dc17878fefa0dd2dc58b40fffb34b8d255d5a7fd2a82e`. `sources/` bewaart ophaalrecords, identiteiten en de gecontroleerde paginaweergaven. De oude SWAP-sitekoppeling gaf404; WUR leverde het oorspronkelijke rapport normaal met200. De actuele webpagina is afzonderlijk op URL, ophaaldatum en hash vastgelegd. Geen derden zijn benaderd.

De volledige SVN-wijzigingsgeschiedenis en een formele ontwerpbeslissing achter de GEM-commentaarregel zijn niet beschikbaar. De bestandsheader bevat een SVN-identiteit, maar bewijst niet wanneer of waarom precies deze regel is toegevoegd. Deze ronde pretendeert die historische auteursintentie niet te reconstrueren.

## Vastgesteld fysisch contract

De historische handleiding beschrijft twee parallel berekende mechanismen voor instroom in onverzadigde matrix: sorptie en Darcy-instroom uit de lokale drukgradiënt. De grootste rate bepaalt de potentiële instroom; onder natte condities is juist Darcy relevant. Verzadigde uitwisseling wordt afzonderlijk over de verzadigde diepte behandeld. De huidige officiële beschrijving handhaaft deze keuze en specificeert ook de bestaande sorptie-/repellentiefactor. Geen van deze beschrijvingen geeft een aanvullend interval `h_enpr≤h<0` waarin Darcy-instroom zonder alternatief moet verdwijnen.

Het air-entry-parameter beïnvloedt de hydraulische curves; het is niet automatisch de phreatische grens van deze uitvoering. Dat onderscheid wordt door de oorspronkelijke code bevestigd:

1. `CALCGWL` zoekt de grondwater-/verzadigingsgrens op de overgang rond `h=0`.
2. De standaard `WATCON`-tak gebruikt bij negatieve `h_enpr` een polynoomnabijheid die tot h0 loopt. Zij maakt de matrix bij `h=-10` niet al exact verzadigd.
3. `ABSORPTION` wordt al begrensd door onverzadigde/perched zone, natte macroporiënwand en domeinpositie. In deze lus heeft de extra `H<h_enpr`-test geen gedocumenteerde overdracht naar de afzonderlijke verzadigde uitwisseling.
4. `SWDARCY`, positieve macroporiedruk, `max(0,HMp-H)`, sorptie/Darcy-selectie, bestaande reductie en voorraadbegrenzing blijven zelfstandige onderdelen van het contract.

De sprong is dus **bewust geïmplementeerd schakelgedrag**, maar voor deze veldroute **geen ondersteund bedoeld fysisch nulpunt van de Darcy-term**. De foutclaim is nauw: implementatie versus aantoonbaar gedocumenteerd procescontract in de onderzochte configuratie. Zij is geen algemeen oordeel over alle historische GEM-toepassingen of alle hydraulische opties.

## Concrete tegenspraak op de oorspronkelijke toestand

De reeds geselecteerde rechterzijde van het drukhoogtepaar geeft voor compartiment45, bodemlaag5 en het betrokken macroporiëndomein:

| Grootheid | Waarde |
| --- | --- |
| Matrixdrukhoogte | `-9.9999999 cm` |
| Macroporiedruk | `4.099979577155267 cm` |
| Positieve drukgradiëntterm HMp−H | `14.099979477155268 cm` |
| Matrix-vochtdeficit θs−θ | `7.22863459736156e-5` |
| Gebruikte geleidbaarheid | `2.429272972972973 cm/d` |
| Gedocumenteerde ruwe Darcy-hoeveelheid voor deze dt | `2.456290005697688e-5 cm` |
| Werkelijk oorspronkelijke ruwe Darcy-hoeveelheid | `0 cm` |

Dit is geen afronding of de bestaande `1e-8`-vochtdeficitgrens: het gemeten deficit is groter. De bovenkant van de verzadigde zone blijft compartiment51, niet45. De natte wand en positieve macroporiedruk blijven gelijk. Er wordt bij45 dus ook geen corresponderende verzadigde Darcy-term geactiveerd. De oude air-entry-test maakt `DelH=0`, terwijl de oorspronkelijke drukgradiëntwet hier positief is. De onafhankelijke contractbeoordelaar controleert die tegenspraak vóór eventuele beschikbaarheidsbegrenzing.

Een afzonderlijke bronobservatie is dat `cofgen` per **node** wordt gevuld en `h_enpr(1:numnod)` aan `cofgen(9,1:numnod)` gekoppeld is, terwijl de oude test `lay` als tweede index gebruikt. Alle air-entry-invoerwaarden in deze oorspronkelijke Andelst-case zijn echter −10. Dat indexgebruik kan deze sprong dus niet verklaren. Er is geen heterogene nieuwe parametercase gestart en geen afzonderlijke indexpatch geclaimd.

## Eén minimale experimentele correctie

`minimal_contract.patch` wijzigt uitsluitend de Darcy-voorwaarde binnen de reeds geselecteerde onverzadigde route:

```diff
- if (H(ic) < cofgen(9,lay)-1.d-8 .AND. HMp > 1.d-8) then
+ if (HMp > 1.d-8) then
```

`DelH=max(0,HMp-H)` blijft ongewijzigd. Alle andere formules, eligibility, `SWDARCY`, niet-negatieve drukgradiënt, sorptie-/Darcymaximum, analytische afgeleiden, beschikbaarheidsbegrenzingen, snelle drainage, gepaarde uitwisseling, toleranties, dtgrenzen en oorspronkelijke reductiewet blijven staan. Er wordt geen overgang gladgestreken of nieuwe fluxfunctie ingevoerd.

De kandidaat vervangt geen verwijderde air-entry-sprong door een nieuwe expliciete negatieve head-drempel. Het bestaande buitenliggende zone-/wandfilter bepaalt reeds waar de onverzadigde term mag werken. De overdracht bij de phreatische h0-grens zelf blijft een afzonderlijk, nog niet gekwalificeerd grensgeval.

Voor de proef blijft de volledige oorspronkelijke V1-prefix onveranderd. Pas op de exacte levende begincontext schakelt een kleine **harness-only** selectie de kandidaat in. Deze selectie is geen fysische toestand en staat niet in de voorgestelde éénregelige legacy-patch. Er is geen datum- of kalenderafhankelijkheid aan een fysische wet toegevoegd. De extra trace schrijft alleen al berekende lokale componenten en identificeert zo de suppressie; het baselinecontroleprofiel reproduceert alle bestaande primitieve operator-/begin-/geheugenbestanden byte voor byte.

## Lokale en gekoppelde kwalificatie

Alle definitieve profielen (`BASE_RIGHT`, `PATCH_RIGHT`, `PATCH_LEFT`, `PATCH_SOLVE`) zijn werkelijk uitgevoerd op native gfortran16.2.0 Windows, O0 en O2. **Alle ruwe uitvoerbestanden zijn bytegelijk O0/O2.** De acht definitieve routes kosten samen `8.567 s`; de langste `1.447 s`, ruim binnen twintig seconden per route.

Dezelfde oorspronkelijke drukhoogtepaarvector blijft behouden, behalve de reeds geselecteerde h45-variatie:

| q45-verandering tussen −10±1e−7 cm | Waarde |
| --- | --- |
| Oorspronkelijke operator | `-0.1279200635526785 cm/d` |
| Gecorrigeerde operator | `-2.3936974624660934e-9 cm/d` |

De positieve gedocumenteerde Darcy-term wordt met de kandidaat exact teruggevonden, inclusief de ongewijzigde factor voor waterrepellentie. De oude scherpe sprong in dit lokale paar verdwijnt; er is geen algemene gladheidsclaim voor alle procesovergangen.

De echte gekoppelde V1-berekening begint vanuit exact dezelfde oorspronkelijke context en stapgrootte als de eerdere afwijzing. Zij accepteert nu in **drie iteraties**, met `IDecMpRat=0` en daadwerkelijk gebruikte `FrReduQ=1`. De verse V1-eindcontrole geeft lokaal `1.1702493141196868e-9 cm/d` en totaal `-2.479530817331362e-9 cm/d`, tegenover de ongewijzigde grenzen1e−6 en1e−5. De geaccepteerde h45 is `-9.898230699732077 cm`. Dit is een echte matrixheroplossing, geen acceptatie na alleen fluxverversing, en gebruikt geen nieuwe algemene solvervariant.

## Onafhankelijke geaccepteerde inventaris en procesgeheugen

Na de echte oorspronkelijke `SoilWater(3)`-/`MACROSTATE`-overgang reconstrueert de losse beoordelaar de primitieve inventaris, Darcy-interfacefluxen en residuen, zonder de uit behoud afgeleide `FLUXES`-vector als sluitbewijs te gebruiken.

| Grootheid | Waarde |
| --- | --- |
| Matrixvoorraadverandering | `+2.216588643188464e-4 cm` |
| Macrovoorraadverandering | `-2.924690851945303e-4 cm` |
| Matrixbalansfout | `-3.506586026321562e-13 cm` |
| Oppervlaktebalansfout | `0 cm` |
| Gecombineerde balansfout | `-3.505277800875187e-13 cm` |
| Grootste afzonderlijke domeinbalansfout | `1.308e-16 cm` |
| Onafhankelijk donor/ontvanger-uitwisselingsverschil | `6.939e-18 cm/d` |
| Verschil onafhankelijk/modelresidu | `6.939e-18 cm/d` |

Alle vijf domeinvoorraden blijven niet-negatief zonder actieve negatieve-voorraadclamp; hun compartimentsommen sluiten tot afronding. De gecombineerde kleine fout is consistent met dt maal het geaccepteerde totale residu. De kwalificatie gebruikt dezelfde oorspronkelijke residugrenzen en alleen een machine-epsilon-envelop voor onafhankelijke aggregatie.

De geaccepteerde sorptieklok is werkelijk bijgewerkt. Het grootste klokveld daalt van `0.030686666429412243` naar `0.020161421096747557 d`, omdat de oorspronkelijke selectie bij Darcy-dominantie sorptie-events afsluit. Dit is een geaccepteerde procesovergang met veranderde fysische uitwisseling, geen bewijs van een rollbackfout. De volledige klok-/eventvectors zijn bewaard; een eigen restart en een gecorrigeerde echte afwijzing/directe-retryvergelijking zijn hier niet gekwalificeerd.

De oorspronkelijke werkelijke afwijzings-/herstelprefix vóór de geselecteerde context blijft via het exacte beginbewijs geërfd. De nieuwe kandidaat zelf wordt in deze context direct geaccepteerd. Er is geen kunstmatige afwijzing geforceerd en geen nieuw scenario gezocht om een herstel-PASS te produceren. Dit blijft een expliciete uitsluiting vóór eventuele brede referentiekwalificatie.

De grotere nieuwe macrovoorraadverandering is een verwacht gedragsverschil door herstel van de eerder onderdrukte Darcy-term. Een kleine dagelijkse balans of overeenkomst met SWAP5 is niet als juistheidscriterium gebruikt. De langetermijngevolgen voor referentietrajecten zijn nog onbekend.

## Bewaarde tussenstappen en bewijsgrenzen

Eén initiële linkerfout betrof het nieuwe diagnostische controlemodule-object; de mislukte bouw is bewaard in `setup-build/` en geen onvolledige executable is gestart. Drie voorlopige O2-proeven met een naar h0 verplaatste expliciete head-gate zijn bewaard in `preliminary-zero-gate/`, inclusief executable en bronidentiteiten. Zij toonden reeds drie-iteratieconvergentie. Vóór definitieve kwalificatie is de correctie verder tot verwijdering van uitsluitend de overbodige uitsluitingsclausule teruggebracht, zodat geen nieuwe epsilon-headgrens wordt geïntroduceerd. Die drie voorlopige routes kwalificeren de definitieve postimage niet; daarvoor zijn de acht definitieve O0/O2-profielen uitgevoerd.

De bronnen/objecten uit STATE02 en STAGNATION05 zijn op hun capsulesha gecontroleerd. Alleen de harnessmodule, de geobserveerde macroratekopie en de geselecteerde soilwaterdriver zijn opnieuw gebouwd en gekoppeld. De originele V1-headcalc, haar beproefde diagnostiek en de oorspronkelijke overige closure blijven geërfd. De definitieve bron-/executablehashes, compile/linkcommando's, elf korte runrecords, bronrecords en alle vectors zijn bewaard. Er is geen tweedaagse eindcampagne, vier-dt-campagne, 481-daagse run, extra procesgeheugenpatch of nieuwe Jacobiaan uitgevoerd.

## Besluit en kleinste vervolg

De codekeuze was opzettelijk, maar de **gemeten sprong is voor het gedocumenteerde veldcontract een implementatiefout**: de code verwijdert een positieve Darcy-term zonder dat de matrix naar de verzadigde route overgaat. De primaire documentatie, originele hydraulische/zonecode en concrete componentmeting ondersteunen samen de éénregelige correctie. De solververbetering is een gevolg en geen zelfstandig bewijs voor een andere fysische wet.

De nieuwe kandidaat V1 plus deze patch is daarom geschikt voor verdere **afgebakende** B1-kwalificatie met expliciete uitsluitingen. Nog open zijn gecorrigeerde afwijzing/rollback/directe retry, droge-eventafsluiting, eigen korte herstart, h0-overdracht, andere hydraulische opties en variërende air-entry-lagen, en trajectnauwkeurigheid. Geen van die grenzen wordt op basis van één succesvol nat contextgeval groen verklaard.

De kleinste volgende stap is één oorspronkelijke onderscheidende procesovergang met de kandidaat te kwalificeren, inclusief echte afwijzing, herstel en geaccepteerde voortzetting, onafhankelijke voorraadcontrole en een korte eigen herstart. Selecteer droge-event- of h0-overdracht alleen wanneer een volledig oorspronkelijke toestand beschikbaar is; start geen nieuwe scenariozoekcampagne. De officiële B1.12, B0, canonical, actieve werkstromen en releasebasis blijven ongewijzigd. Geen promotie-PR of macroporiënmigratie is gestart.

Gegevenscontrole zonder modellen: `python research/swap431-macro-b1-contract06/assess_contract06.py`.
