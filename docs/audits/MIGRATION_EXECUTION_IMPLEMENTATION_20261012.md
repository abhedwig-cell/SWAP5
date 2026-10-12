# Implementatievolgorde en te behouden regels

**Status: Proposed**, voortbouwend op het
[onderzoek](MIGRATION_EXECUTION_ANALYSIS_20261012.md). Geen actuele workflow,
evidence, contract of tolerantie wordt door deze analyse veranderd.

| Prioriteit | Aanpassing | Type | Uitvoering en beoordeling |
| --- | --- | --- | --- |
| 1 | Kies één functionele productieroute en dependencyclosure per opdracht | Direct, geen code | Gebruik bestaande ownerstatus; kleine checkpoints zijn geen sessie-einddoelen. Begin met de RAINTB-proef |
| 2 | Hervat status-first, controleer exact delta en opgeslagen bronhash | Direct, geen code | Bestaand AGENTS/protocol toepassen. Meet herhaald onderzoek prospectief; geen nieuw repositoryregister |
| 3 | Reconcile ledger en canonical ownerreceipt bij afsluiting | Direct, geen code | Eerst warmte-dispositions door masterowner herstellen; geen stale ACTIVE als fysisch tekort tellen |
| 4 | Plan gedeelde sciencebesluiten vóór afhankelijke implementatie | Direct, geen code | Cropfase, Snow/layout, HY/grid en drainage/coupling blijven bestaande eigenaarwerk. Concrete beslissing en gates, geen generieke nieuwe commissieronde |
| 5 | Bundel documentaire closeouts; kwalificeer stabiele route | Direct, geen code | Gebruik bestaande docs/hashchecks en toegestane inheritance; exact admissionreceipt behouden. Brede rerun na relevante reparatie blijft verplicht |
| 6 | Bestaande runnercontrol uitbreiden met tijd/event/reason-for-rerun | Kleine tooling, apart | Voeg optionele proefmetadata toe aan owning status/log; old records niet retrofiten. Test provenance, interrupted/failed status en ontbrekende datums |
| 7 | Read-only dependencyselector in shadow mode | Kleine tooling, apart | Geef RUN/INHERIT/UNKNOWN-advies naast huidige gates; nog niets overslaan. Include/shell/generated/data/config/compiler/sourceguardclosure verifiëren; mutation-controls moeten gemiste dependencies afwijzen |
| 8 | Dubbele suiteoproepen en frozen inheritance automatiseren | Grotere kwalificatiewijziging | Pas na shadow validation en VQ/F-CI review. Cachekey omvat exacte transitive inputs, argumenten, omgeving, claim en authority. Originele logs/refs blijven immutable; moving gates blijven zelfstandig |
| 9 | Workflowtriggers en frozen/moving scheduling herontwerpen | Grotere kwalificatiewijziging | Afzonderlijke PR: changed-path en transitive-trigger tests plus checks-policy-review. Beoordeel push én PR, concurrency, mergecheckout en runnerimage. Meet jobcount/startdelay vóór en na; geen runnerbesparing claimen uit YAML alleen |

De historische [F-TA04 PR172](https://github.com/abhedwig-cell/SWAP5/pull/172)
benoemt bestaand F-TA02 impact-selectionwerk;
dit is niet als huidige canonical selector aangetroffen. Vóór een nieuwe tool
bouwen eerst de exacte branch/recovery en huidige admission reconstrueren.
Dubbele tooling ontwikkelen is geen procesverbetering. Ook CI-triggertriage bestaat
al in PROJECT-CONTROL; bouw daarop voort.

Prioriteiten 1-5 behoeven geen herontwerp van de wetenschappelijke gates en kunnen
binnen bestaande autorisatie worden toegepast. Het voorgestelde uitvoeringsmodel
is een concrete leeswijze van bestaande regels, geen automatische vervanging van
het protocol. Na de proef kan een korte verduidelijking van “small slices” versus
functionele werkpakketten in de bestaande workstreams/protocol worden voorgesteld.

Automatisch gates overslaan op basis van een selector is geen gewone administratieve
optimalisatie. Vereis daarvoor een afzonderlijke F-CI/VQ-beslissing, behoud een
conservatieve fallback en verifieer false-negative-impact met doelbewuste veranderingen
in directe én indirecte inputs. Vergelijk met de huidige brede suite; iedere
onbegrepen mismatch valt terug op RUN. Eén geslaagde proef bewijst geen algemene
architectuurneutraliteit of onveranderd regressierisico.

## Regels die intact blijven

Full Richards blijft de productie-/referentieroute; gecertificeerde referentietrajecten
en exact historische B0/B1/B2-bronautoriteit blijven geldig binnen hun scope.
Massabalansen, numerieke/temporal-toleranties en onafhankelijke oracles worden niet
versoepeld. State ownership, trial/accept/retry/rollback, rejected-state nonmutation,
restartcoherentie en exactly-once receipts blijven bindend.

De SWAP5-MODFLOW-contracten voor fysieke paths, heads, units/areas, donor-/storage-
ownership, mass en joint continuation blijven ongewijzigd. Relevante actuele
F-CI preservation, nieuwe-physics ownerkwalificatie, exact postimage-/mergetreecontrole
en reproduceerbare canonical admission blijven vereist. Evidence inheritance
blijft beperkt tot bewezen ongewijzigde relevante dependencies; onzekerheid is RUN.
Implemented, persisted, tested, qualified, preserved en admitted blijven afzonderlijk.

## Beslismoment na de proef

Beoordeel functionaliteit en veiligheid eerst, proceskosten daarna. Neem alleen
verbeteringen over waarvoor traceerbare besparing of vermeden duplicatie bestaat
en geen ongeadresseerde kwalificatiecoverage verdwijnt. Ongelijke scope of ontbrekende
historische arbeidstijd geeft INCONCLUSIVE, geen verzonnen winstpercentage.
Bij een fout door te late detectie verklein de bundle of voeg een focused gate toe;
bij een echte shared-contractblokkade verbeter readiness, niet de tolerantie.
Leg het besluit in de bestaande proef-/ownerreceipt vast en vervolg de eerstvolgende
dependency-ready productieroute. Geen nieuwe verplichte administratieve laag.

## Actuele vervolgkeuze na de proeven, 12 oktober 2026

**Status: Proposed vervolgwerkpakket; geen productieautorisatie of admission.**
Deze aanvulling vervangt geen eerder bewijs. De RAINTB-proef is inmiddels
begrensd admitted via [het proefresultaat](MC_MET01_PILOT_RESULT_20261012.md)
en PR1212. De opt-in build-cache V1 is admitted, standaard uitgeschakeld;
zie [contract en resultaten](../development/FCI_BUILD_CACHE_TRIAL_20261012.md).
De afgeronde V2-proef blijft op [PR1214](https://github.com/abhedwig-cell/SWAP5/pull/1214):
11 controles en zes fysieke O0/O2-routes PASS; warme sensor 24,8% sneller,
warme root 1,1% langzamer, eerste root-vulling 154,7s extra. Eén geordende
meting per route bewijst geen algemene migratieversnelling. Geen verdere
micro-optimalisatie of standaardinschakeling volgt uit deze uitkomst.

Readiness is opnieuw onderzocht op canonical
`cccb898ac8b3b7d16515c98e3e67eb1802c4bc5f` en master PR1072
`cece0a4e724944a913a5e7c6eb00a7fc28a7370c`. Structurele hertelling van de
243 unieke rijen: 95 ADMITTED, 108 ACTIVE_MIGRATION, 14 SUPERSEDED,
2 REJECTED, 20 NOT_APPLICABLE en 4 QUALIFICATION_ONLY. Dit is geen volledige
source-censuskwalificatie. De masterstatus bevat oudere samenvattingsvelden;
voor deze selectie zijn de actuele capabilityrijen en queue gelezen, niet
alleen die historische samenvatting.

De 16 actuele open PR's waren 58, 365, 389, 486, 528, 700, 740, 953, 956,
987, 1009, 1072, 1098, 1103, 1117 en 1214. Geen titel/branch identificeerde
een afzonderlijke actieve PMtraditional/CFBS-kandidaat. Dit bewijst niet dat
ownership vrij is: bestaande PPA/RT/MC-MET01-authority blijft beslissend en
nieuwe owneractiviteit moet vóór implementatie worden gereconcilieerd.

| Kandidaat | Actuele grens | Besluit voor deze vervolgopdracht |
|---|---|---|
| Crop-oogst/rotation/fallow | Onbesliste morning-publicatie op reeds geaccepteerde carrier; RT/HY/F-KT en crop/restart gedeeld | Niet zelfstandig implementeren; behoud bestaande [fasebeslissing](../science/MC_CROP01_HARVEST_ROTATION_PHASE_DECISION.md) |
| Irrigatie/NUT-SOL/HYD/drainage | Actieve afzonderlijke owners en gedeelde application/coupling-contracten | Niet overnemen |
| Brede RAINTB-afsluiting | Parser, kalenderbibliotheek, eventcoalescing, rooted/interception en diskcodec zijn verschillende closures | Geen kunstmatige fullcap-bundle; begrensde pilot behouden |
| Dagelijkse PMtraditional plus CFBS | Twee concrete MC-MET01-gaten op dezelfde demand-/forcingroute; independent physics vereist | Geselecteerd coherent vervolgontwerp onder bestaande PPA/RT-routing |

### Functioneel doel en veilige omvang

Werkpakket: **dagelijkse traditionele Penman-Monteith en branchespecifieke
CFBS-bodemvraag door bestaande geauthenticeerde meteorologie naar echte
geaccepteerde Full Richards-hydrologie, inclusief retry en joint restart**.
Betrokken master-ID's: `SW431-ET-PMTRAD` en `SW431-ET-SOILFACTOR`.
De relevante masterqueue vermeldt voor beide geen capability-afhankelijkheid.
Dat is geen bewijs dat de gedeelde runtime-interface al gereed is.

Eerste fysieke envelope: bestaande root-free BASE/AIR/no-snow/default-MVG
bottom7-weatherroute, dagelijkse invoer, bestaande uniforme neerslag mode0.
Vergelijk SWETR=1 met CFBS aan/uit en SWETR=0/SWDIVIDE=0 met CFBS aan/uit.
Bewijs werkelijke bodemverdamping, aanhoudende accepted hydrologie en herstel
op meerdere authentieke dagen. De productiegetuige gebruikt canopy/parameters
uitsluitend volgens de overeengekomen ownerroute; een caller-scalar met
gefingeerde weatheridentity is geen integratiebewijs.

Pure bronkwalificatie omvat daarnaast gedeeltelijke/volledige cover,
emergence aan/uit, SWCF aan/uit, relevante weerstand- en CO2factoren en
pondvraag. Een root-free productietest bewijst geen gewastranspiratie of
rooted lifecycle. Rooted/interception, detailed-record PM, nieuwe
crop-seizoenen, MODFLOW, Snow en diskcodec blijven buiten deze opdracht.
Als deze beperkte envelope niet voldoet aan de volledige masterbetekenis,
blijven beide ID's ACTIVE met een bounded receipt. Twee geselecteerde ID's
betekenen niet vooraf twee admitted capabilities.

Bundel bronanalyse, pure providers, branchespecifieke CFBS, opt-in binding en
restart in één branch en één admissioncyclus voor het complete gekozen traject.
Geen aparte productie-PR voor een scalarfactor, daarna een selector en daarna
pas runtimebinding. Splits alleen bij een echte onbesliste shared interface of
wanneer ownerkwalificatie verschillende admissiongrenzen vaststelt. Iedere
nieuwe formule houdt een onafhankelijke oracle en gerichte tussenchecks.

### Bronbewijs en een belangrijke semantische valkuil

Hergebruik de aanwezige B1.11-bundle
`integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`, member
`SWAP/MOD_meteo.f90`, SHA256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.
Memberhash is bij deze readiness opnieuw geverifieerd; geen nieuwe zoektocht
naar een historische zip is nodig.

ETpot regels 1411-1426 schalen bij SWETR=1 alleen es0 met CFBS; ep0 en et0
houden hun eigen factoren. Regels 1438-1452 verzorgen de traditionele
postprocessing; regels 1458-1479 bepalen omzetting, nonnegative clipping en
CO2/wet-canopyverwerking. Penmon regels 1917-1947 gebruiken ongeschaalde
aerodynamische weerstanden en nul wet-soilweerstand in de traditionele branch.
**Bij SWCF=1 én SWCFBS=1 wordt es0 daar eerst uit de crop-PM-component
berekend, vóór de CFBS-vermenigvuldiging in ETpot.** Alleen de bestaande
bodemuitkomst vermenigvuldigen is dus niet algemeen bron-equivalent. Evenmin
mag CFBS de volledige ETforcing schalen. Een oracle moet juist deze twee
verkeerde implementaties met onderscheidende fixtures afwijzen.

Bovenstaande regels zijn locators, geen zelfstandige volledige oracle.
Neem ook de volledige penmon/astro/raero closure, constante- en
parameterautoriteit, eenheden en geldige inputranges mee. Gebruik letterlijk
gecompileerde historische rekenpaden of onafhankelijk geadjudiceerde
referentie-executie; spiegel de nieuwe implementatie niet als haar eigen test.
Behoud bestaande tolerantieautoriteit. Een onverwachte brondefect/discrepantie
vereist de bestaande reference-policybeslissing, geen stilzwijgende correctie.

### Readiness, implementatievolgorde en eigenaar

Eigenaarroute: bestaande REGIE/PPA/RT voor MC-MET01; onafhankelijk VQ/F-CI
kwalificeert nieuwe science en preservation. Behoud MC-CROP01, root, HY,
interception en gekoppelde MODFLOW-owners. Dit plan benoemt geen nieuwe persoon
of tweede stateowner. Readiness: **SOURCE_READY; APPLICATION_CONTRACT_TO_BOUND**.

1. Lees status-first AGENTS/protocol, `MC_MET01_STATUS.json`,
   `PPA_WU03_STATUS.json`, huidige Status-A/current-canonical authority en
   de twee masterrijen. Pin live HEAD en reconcile relevante delta/open peers.
   Hergebruik bronhash en compileropstelling; controleer actuele beschikbaarheid
   en identiteit, niet alleen een oud scratchpadpad.
2. Leg in het bestaande MC-MET01-record de opt-in selector/CFBS-ingang,
   canopy/site-autoriteit, output-eenheden, forcingprovenance en volledige
   parameteridentity bij restore vast. Huidige file-weather gebruikt de
   reference-ET route; de aanwezigheid van een PMdirect pure module is geen
   bewijs van een geauthenticeerde PMtraditional-runtimebinding. Ontwerp de
   additive route vóór editing; geen automatische verruiming van de huidige
   SWETR=1/PPA-envelope of private flag-bypass.
3. Bouw onafhankelijke literal oracles en vervolgens begrensde pure evaluators.
   Richt O0/O2-checks op alle branches, factor 0/1/anders binnen bronrange,
   covergrenzen, emergence, SWCF-combinaties, units/clipping, ongeldig/NaN/
   overflow en disabled-parametersemantiek. Behoud defaults en PMdirect.
4. Bind beide modes aan dezelfde bewaakte weather/forcingroute. Parameters
   zijn immutable configuratie, geen nieuw mutable statekanaal. Bewijs
   positive-window uitvoering, dezelfde dag in subintervallen, meerdere dagen,
   werkelijk evaporationverschil waar de fixture dat toelaat, rejected-state
   nonmutation, retry, exactly-once en continuous/restored statevectoridentiteit.
   Een gewijzigde selector/factor bij restore moet vóór publicatie worden
   afgewezen; herbruik een bestaand codeccontract alleen als de closure dat toestaat.
5. Kwalificeer de stabiele complete route eenmaal met onafhankelijke owner/VQ,
   toepasselijke original PPA/full F-CI en alle door de feitelijke closure
   getroffen hoogste/root/frost/crop/reference gates. Iedere latere relevante
   reparatie invalideert de betrokken resultaten. Geen numerieke cache of
   default build-cache gebruiken om deze proef sneller te laten lijken.
6. Reconcile live canonical en overlap, verifieer exacte PR-head/mergetree en
   sourceblobs, voer getroffen mergetreedelta opnieuw uit, leg admissionreceipt
   vast en reconcile de twee masterrijen met de werkelijk bewezen envelope.
   Doc-only closeout gebruikt toegestane closure-inheritance en docs/hashchecks.

Baselines van de bij readiness onderzochte seams:

| Pad | Canonical blob |
|---|---|
| `src/process/mod_reference_et_demand_process.f90` | `f5e88ec5089fd3b57ac111065fab2aa32dde0fae` |
| `src/process/mod_pmdirect_swetr0_process.f90` | `3eb23d075a56ba1158f4758f75a8d94c94e09b39` |
| `src/adapter/mod_swap_daily_weather_file_adapter.f90` | `cb53d90e9861bddf83b3ededf8993869cf5c8308` |
| `src/adapter/mod_ppa_wu03_common_forcing_adapter.f90` | `7ddaaddcedc04fad6ba9d38ca4626332014f8d5b` |
| `src/runtime/mod_fmr_production_application_bootstrap.f90` | `2ae6e3aafe9f4987b562618443b0ccd48a133a4c` |

Gerichte bestaande regressie-ingangen: FPM06A, FVQ35/FVQ36, FMR23,
F-APP03/F-APP04 PMdirect en originele `tests/fapp/run_ppa_wu03_preservation.sh`.
Gebruik de betreffende bestaande runner-/authoritypaden en hun complete inputs;
geen wildcardlijst als bewijs van gesloten afhankelijkheden. De adapter,
bootstrap en state/restartcallers bepalen welke extra compositiegates noodzakelijk
zijn. Niet elke genoemde pure gate bewijst applicationequivalentie.

### Verificatiebesluiten en meetbare afsluiting

Pas de bestaande A/B/C/D-regels uit het uitvoeringsmodel toe. Nieuwe
PMtraditional/CFBS-science en affected transaction/mass/restartclaims zijn RUN.
Ongewijzigde historische bronidentiteit is herbruikbaar. Existing incumbent
science is uitsluitend INHERIT wanneer exacte runner/source/fixtures/config/
compiler/environment/authorityclosure en geldige terminal evidence dat bewijzen;
bij ontbrekende closure RUN. Moving-current F-CI blijft zelfstandig wanneer
zijn autoriteit dat eist. Documentation/receipt zonder execution-impact krijgt
geen zelfstandige numerieke rerun. Nog geen automatische selector of gate-omissie.

Meet prospectief in de bestaande status en runnercontrol: UTC stagebegin/einde,
exacte SHA/inputs, RUN/INHERIT met reden, terminal resultaat en failureherstel.
Leg actieve sessiestart/stop apart vast; ontbrekende tijd blijft UNKNOWN.
Tel hetzelfde bronhash/vraag-paar alleen als heronderzoek zonder relevante delta.
Tel identieke reruns apart van noodzakelijke invalidation-runs. Tel gebruikers-
hervattingen, inhoudelijke besluiten en runtimeonderbrekingen afzonderlijk.
Rapporteer functionele trajecten en volledig admitted master-ID's afzonderlijk.
Bewaar fouten inclusief detectiefase; nul gevonden regressies bewijst geen nulrisico.

Baseline: RAINTB PR1212 is één coherent traject met één admissioncyclus,
49m04s full F-CI, 5m28s PPA en 2h43m53s readiness-tot-admission kalenderduur.
Actieve arbeid en vroegere gatekosten zijn UNKNOWN. Dit nieuwe pakket heeft
andere atmosferische formules en twee selectors; die baseline is een referentie
voor procesgedrag en absolute kosten, geen scope-equivalent snelheidsratio.
Vergelijk geen aantallen PR's of capabilities als vervanging voor complexiteit.
Een causale procentuele tijdwinst blijft INCONCLUSIVE zonder passende comparator.

Acceptatie: onafhankelijk exacte historische science binnen de verklaarde
inputscope, alle vereiste O0/O2/mass/transaction/retry/restart/preservationgates,
geen ongeadresseerde regressie of versoepelde tolerantie, reproduceerbare
exacte admission en correcte bounded/full disposition. Procesacceptatie vereist
één voltooid functioneel resultaat, geen routine-stop na checkpoints en geen
onverklaarde identieke brede rerun. Full Richards, gecertificeerde referenties,
MODFLOW-contracten en alle bestaande fysieke veiligheidsgrenzen blijven intact.

Deze vervolgopdracht is een ontwerp voor de volgende productie-Work-sessie.
Deze analyse verandert geen productiecode of bestaande kwalificatie-evidence.
Bij een echte shared-contractblokkade wordt uitsluitend de afhankelijke route
gepauzeerd met exact owner/keuze/next_action; geen ontbrekende-sourceclaim of
algemene verzoeken om opnieuw "go".
