# NATIVE09 — beperkte native macroherstart geïmplementeerd

**PASS voor de oorspronkelijke B-checkpoint en één gelijktijdige fysieke vervolgstep, met O0/O2.** De verse native eigen-bestandsherstart herstelt de geaccepteerde macrotoestand, exacte tijd en volgende dt. De context vóór headcalc, solveruitkomst, volledige gemeten fysieke eindtoestand, bodemtemperaturen en hydraulische geleidbaarheden zijn bytegelijk aan de continue route. De oorspronkelijke echte afwijzing, rollback en kleinere retry blijven exact behouden.

De kandidaatstatus blijft **B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS**. Dit is geen toelating van een algemene macroherstart, cumulatieve uitvoercontinuïteit of officiële B1-opvolger.

## Scope en identiteit

Basis is RESTART08 `cd2bf853efeae56775a2e917f2f60701697ba34c`; onderzoek op `research/swap431-macro-b1-native09-20261114`. Canonical is vooraf gereconcilieerd op `01f44996a0bbe812b7c981e2060cdbbf0554283c`. De nieuwe canonicalwijzigingen betreffen no-macro Python-hostbeleid en kwalificatie; de oorspronkelijke macro-Fortranclosure is niet gewijzigd. B0, B1.12, canonical, release en andere werkstromen blijven onaangeraakt.

Alle modelroutes gebruiken dezelfde oorspronkelijke B-context en dezelfde V1 plus CONTRACT06-Darcypatch. Er is geen nieuwe fysica, solvervariant, tolerantie, tijdstapgrens, reductiewet of aanvullende rollbackpatch. De native uitvoer is nog steeds een oorspronkelijk binair `.end`-bestand, met een herkenbare getypeerde trailer. Geen replay, geïnjecteerde solveruitkomst of later teruggespeelde modelgeschiedenis.

De vier definitieve positieve routes zijn O0/O2 elk: oorspronkelijke echte retry plus continue vervolgstep, en een verse eigen-bestandsherstart met één vervolgstep. Zeven aanvullende O2-routes controleren alleen ongeldige initialisatiebestanden. Langste definitieve route: **1,323 seconde**, totaal definitief ongeveer **3,50 seconden**, geen censuur. De limiet blijft twintig seconden per route. Er is geen volledige tweedaagse of 481-daagse modelroute uitgevoerd.

## Concrete implementatie

`native_state.f90` bevat uitsluitend de versiegebonden toestand voor deze afgebakende route. `FIELDS.json` benoemt de expliciete velden; er is geen algemene runtime- of toestandsserializer. De oorspronkelijke bronaanpassingen staan afzonderlijk in `native_contract.patch`; de nieuwe module komt daarbij. De volledige instrumented compilatiebronnen zijn eveneens bewaard.

De trailer bewaart actieve domeinen/compartimenten: macrovoorraden, lopende sorptieklok/referentie/beginsorptiviteit, geaccepteerde scheurgeometrie en coherente niveau-/wand-/oppervlaktecaches. Daarbij komen exact tijdstip, volgende dt, relevante tijdstap-/dagfase en de actuele dagelijkse forcing-, gewas- en Ruttercontext. Directe caches blijven behouden om geen tweede geometrie-algoritme te introduceren. Het volledige eigen bestand is **38.972 bytes**. Overbodige maximale arraycapaciteit wordt niet weggeschreven.

De oorspronkelijke native lezer leest eerst H, pond, warmte, verdampingsreservoirs en bestaande gewasvelden. Daarna wordt de complete trailer lokaal ingelezen en gecontroleerd op herkenning, versie/buildidentiteit, dimensies, eindmarker, eindigheid, voorraadconsistentie en geselecteerde fase. Pas daarna ontstaat een pending toestand. Macro-initialisatie bereidt constanten voor, slaat de koude voorraadseed en tijdintegrerende MACROSTATE-aanroep over en installeert de geaccepteerde macrovelden vóór opslag van een nieuwe trialbasis.

Voor deze subdaghervatting wordt het oorspronkelijke TSTART als forcing-/kalenderlaadvenster behouden. De exacte hervattijd komt uit real(8) in het eigen bestand. De native cropreader moet ook bij de oorspronkelijke gewasstart alle opgeslagen croprecords consumeren; zijn oude start-croprotation-uitzondering wordt daarom uitsluitend voor deze binaire macrohervatting uitgeschakeld.

De host leest eenmaal de oorspronkelijke eenvoudige-gewasconstanten met `cropdevelopment(1)`, zonder gewasinitialisatie/groei (`2/3`) of dagstart. Die parameterlezer zet onder andere SICACT tijdelijk op nul; de geaccepteerde context wordt erna geïnstalleerd. Vervolgens worden matrix-hydraulische caches zonder integratie ververst en worden exacte tijd/dt, dagfase, forcing en gewascontext hersteld. De echte volgende hostlus voert meteo, Rutter, drainage, nieuwe trialbasis, headcalc en de volledige water-/integraal-/warmte-/tijdcommit precies eenmaal uit.

De standaard READSWAP-waarschuwing dat oude macro-I/O ontbreekt is ongewijzigd gebleven. Zij beschrijft de oude interface. Alleen de expliciete onderzoeksextensie met trailer en begrensde launcher is hier gekwalificeerd; de waarschuwing mag niet als bewijs tegen of vóór deze extensie worden gebruikt.

## Bewijs op dezelfde B-checkpoint

| Controle | O0/O2-resultaat |
| --- | --- |
| Echte oorspronkelijke afwijzing dt=2×10⁻⁵ dag | Onveranderd na dertig iteraties; trace-index 31, ongereduceerd |
| Rollback en oorspronkelijke kleinere retry dt=10⁻⁵ dag | Onveranderd geaccepteerd in zeven iteraties |
| Alle oude retry-/continue meetvectors versus RETRY07 | Bytegelijk |
| Eigen writer vóór/na I/O, oude én uitgebreide toestand | Bytegelijk |
| Trailerinhoud checkpoint versus geïnstalleerde toestand | Bytegelijk, inclusief klok, voorraad en geometrie |
| Uitgebreide context vóór headcalc | Bytegelijk, inclusief gewasconstanten, temperatuur en geleidbaarheid |
| Vervolgstep | Beide dt=10⁻⁵ dag, drie iteraties, bytegelijke solvervector |
| Eindtijd | Beide t1900=35796,951373333104 |
| Volledige gemeten fysieke eindtoestand en warmte | Bytegelijk |
| Definitieve O0 versus O2 | Alle meetvectors en eigen bestanden bytegelijk |

Checkpointtijd is exact **35796,9513633331**. De maximale sorptieklok **0,020029999740510247 dag** blijft behouden; het eerdere verlies van klok en circa 0,0104 cm macrovoorraad treedt hier niet meer op. Er is geen afronding via de oude tekstdatum.

Vlak vóór headcalc blijven uitsluitend oude debieten/fluxprofielen en een opnieuw te bepalen eventflag verschillen. Deze worden door de echte vector-/rate-evaluatie herberekend. Nieuwe regen-/irrigatie-/overige oppervlakforcing, root- en drainagerates, persistent geheugen en uitgebreide context zijn gelijk. Vanaf de solverreturn en na de volledige commit is ook de oorspronkelijke inventarisdump exact gelijk. Een dump van alle trialcaches vóór herberekening wordt niet ten onrechte als noodzakelijke persistentievoorwaarde gebruikt.

De onafhankelijke reconstructie gebruikt dezelfde bevroren primitive-inventoryfunctie uit RETRY07, zonder daar modellen te draaien. Voor de gelijktijdige vervolgstep:

- lokaal residu 1,3744364×10⁻¹⁰ cm/d, totaal −4,3202365×10⁻¹⁰ cm/d;
- matrixvoorraadverandering 2,2802092×10⁻⁵ cm;
- macrovoorraadverandering −2,7810820×10⁻⁵ cm;
- gecombineerde waterbalansafwijking **−4,284426×10⁻¹⁵ cm**;
- maximale afwijking gepaarde uitwisseling **6,94×10⁻¹⁸ cm/d**.

Dezelfde berekening wordt afzonderlijk op de geherstarte stap uitgevoerd en levert dezelfde resultaten. Alle vijf domeinvoorraden sluiten op afrondniveau. De geaccepteerde retry voldoet eveneens aan de oorspronkelijke residu-/inventariscriteria; haar gecombineerde afwijking is circa 1,445×10⁻¹² cm.

## Negatieve bestanden en behouden ontwikkelbewijs

Ontbrekende trailer, verkeerde versie, afwijkende traileridentiteit, verkeerde dimensie, NaN, negatieve voorraad en afgebroken trailer worden alle met een expliciete fout gestopt vóór installatie en vóór headcalc. Er is geen stille matrix-only fallback. De launcher verifieert vooraf de hashes van alle geërfde begrensde casusbestanden; alleen de vastgelegde SWINCO3/INIFIL/binaire formaatinvoer wordt daarna aangepast.

Dit is een casusgebonden ABI/buildidentiteit, geen native cryptografische controle van willekeurige later gewijzigde invoer of forcing. `CASE_IDENTITY.json` onderscheidt oorspronkelijke auditidentiteit van de bestaande RETRY07-proefinvoer. Alleen SWP wijkt af: de al eerder begrensde TEND, uitgebreidere diagnostische INLIST_CSV en SWEND=1. Alle overige bestanden zijn exact oorspronkelijk. De nieuwe launcher voegt geen fysieke invoerwijziging toe.

Ontwikkelfouten en tussenuitkomsten blijven zichtbaar: `setup-build/` bevat de eerste interface-/arrayshape-compilefout en de hashvergelijking met het lange oorspronkelijke SWP-bestand (geen model gestart). `preliminary-format/` bewaart de eerste string-/croprecordformaatroute; `preliminary-context/` de route met nog onvolledige gewasconstanten; `preliminary-water-only/` de eerste geslaagde waterkwalificatie vóór uitbreiding van de meting met daadwerkelijke temperaturen, geleidbaarheden en cropconstanten. Dit zijn vijftien aanvullende korte routes, waaronder zeven vroeg afgebroken bestandscontroles. Ze worden niet verborgen of als definitieve postimage verkocht. Alleen `data/O0` en `data/O2` dragen de definitieve claim.

## Geldigheidsgrens en herstelpad

Gekwalificeerd is precies de fysieke eigen herstart van de bestaande ongereduceerde B-subdagcheckpoint plus één gelijktijdige vervolgstep, met hetzelfde native ABI, dezelfde invoer en expliciete launcher. KWT, gereduceerde checkpoints/NStep-historie, hysterese, frost, andere hydraulische modi, dagovergangen, droge/event- of h=0-overgangen en volledige trajecten blijven uitgesloten.

Exacte cumulatieve uitvoer/PEARL-ledgers zijn niet gekwalificeerd. De lokale overschaduwing van old-wall in MACROINTEGRAL en de cumulatieve beginwaarden zijn niet veranderd. Dit fysieke PASS is dus geen full-output-restart-PASS. Ook een willekeurig nieuw checkpoint of invoerbestand valt niet automatisch onder deze claim. Er is geen officiële promotie.

Herbeoordeling zonder model: `python research/swap431-macro-b1-native09/assess_native09.py`. De capsule bevat definitieve en mislukte routes, bronnen, executables en vervangende objects, aansluitend op de bestaande vier native capsules. `STATUS.json`, `RESULT.json`, `EVIDENCE.json` en `CODEX_FOLLOWUP.md` vormen het herstelpad. Een volgende proef vereist een concrete nieuwe vraag binnen de nog open grenzen; geen automatische brede campagne.
