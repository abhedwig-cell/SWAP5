# Migratiesnelheid: diagnose en proefvoorstel

**Status: Proposed.** Procesonderzoek van 12 oktober 2026; geen nieuwe fysische
kwalificatie, procesregel of productie-admission. Canonical is vastgepind op
`cdd0c02c0b3a5b7f35c00c7138bd6898a4eb98fc`. De master is afzonderlijk gelezen
op PR1072-head `a0ea55bf3c53237be9ee9c9efa1d560d8c234f64`.

De grootste verdedigbare verbetering is een volledig functioneel werkpakket
ontwikkelen met gerichte tussentests, gevolgd door één kwalificatiecyclus voor
de stabiele kandidaat. Het bewijs ondersteunt vermindering van herhaald werk,
maar bewijst nog geen gerealiseerde versnelling. Daarvoor dient de proef.

De vier resultaten zijn dit onderzoek, het
[uitvoeringsmodel](MIGRATION_EXECUTION_MODEL_20261012.md), het
[proefplan](MIGRATION_EXECUTION_PILOT_20261012.md) en het
[implementatieadvies](MIGRATION_EXECUTION_IMPLEMENTATION_20261012.md).

## Methode en beperkingen

De doelgerichte steekproef bevat 38 PR's: 20 crop, 8 irrigatie, 3 F-CI/gezamenlijke
kwalificatie, 2 root, 1 warmte, 1 drainage, 1 NUT/SOL en 2 integratie/master.
Zowel kleine wijzigingen, omvangrijke productieblokken, documentaire afsluiting,
kwalificatie en niet-gemergede kandidaten zijn opgenomen. Er zijn 32 gemergede
en 6 niet-gemergede PR's. Dit is geen willekeurige steekproef of projectbreed
productiviteitscijfer; crop is bewust oververtegenwoordigd om de opeenvolging te
onderzoeken. Drainage #1056 is een iets oudere vergelijkingscase.

PR-metadata, gewijzigde bestanden en commitmetadata zijn via GitHub gelezen;
de actuele autoriteiten, runners, workflows, bronbundel en herstelrecords lokaal
op het vastgepinde canonical. De bronbundel is daadwerkelijk uitgepakt in geheugen:
`SWAP/MOD_meteo.f90` heeft SHA256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.
De dayend-kwalificatiearchive is eveneens gelezen, inclusief controlebestanden
en terminale logmarkers. Er zijn geen nieuwe wetenschappelijke tests uitgevoerd.

Alle berekeningen en de gebruikte PR-, bestand-, commit- en jobmetadata staan in
het [eenmalige onderzoeksbestand](https://github.com/abhedwig-cell/SWAP5/blob/analysis/migration-execution-20261012/integration/audits/evidence/MIGRATION_PROCESS_ANALYSIS_20261012.json).
Dit is observatiebewijs, geen nieuw verplicht register. Commitdatums zijn
committerdatums van de momenteel zichtbare geschiedenis. Rebase, squash,
recompositie en overgenomen commits maken deze ongeschikt als arbeidstijd.
Voor #1196 ligt de eerste zichtbare commit zelfs na PR-opening. Een oorspronkelijke
starttijd wordt daar niet uit afgeleid. #1117 heeft slechts 100 van 342 commits
in de opgehaalde pagina; alle 131 bestanden zijn wel gelezen. #58 is een
integratiecarrier met 8595 commits en 5657 bestanden: commitpagina en bestandslijst
zijn onvolledig, respectievelijk 100 en maximaal 3000. Die PR wordt alleen gebruikt
voor de integratierol, niet als meetbaar migratiewerkpakket.

| Grootheid | Wat het bewijs meet | Grens |
| --- | --- | --- |
| Kalenderduur PR | merged_at minus created_at | Geen totale migratieduur |
| Commit tot merge | eerste zichtbare committerdatum tot merge, bij complete lijst | Geen sessiestart of actieve tijd |
| Jobduur | completed_at minus started_at | Inclusief setup; geen CPU-tijd |
| Eerste jobvertraging | eerste jobstart minus run creation | Planning/startvertraging; geen bewezen runneroorzaak |
| Lokale gateduur | started_utc tot ended_utc in controlbestand | Alleen de genoemde gate |
| Actieve ontwikkeling, Work-interventies, lees-/zoektijd | UNKNOWN | Geen complete sessietelemetrie |
| Ownershipwachttijd en herstelarbeid | UNKNOWN | Een zichtbaar besluitgat heeft geen gemeten arbeidsduur |

Overlappende runs worden niet opgeteld als verstreken tijd. Overlappende PR's
#1123/#1125, #1126/#1195 en #1197/#1204 zijn geen onafhankelijke productie-output.
Toevoegingen onder `src/` betekenen een productiecodewijziging, niet automatisch
nieuwe historische functionaliteit. Base64-archives vergroten regeltellingen.

## Toetsing van de voorlopige hypotheses

De mediane open-tot-mergeduur van de 32 gemergede PR's is **595 seconden**.
9 van 32 sluiten binnen 60 seconden. “De meeste PR's worden binnen seconden
gemerged” geldt dus niet voor deze steekproef. #1204, #1206, #1207 en #1209 sluiten
wel na 93, 246, 47 en 33 seconden. Bij deze vier productieblokken liggen bronwerk,
ontwikkeling en grote lokale kwalificatie grotendeels vóór PR-opening.
#1160 blijft 4 uur 46 minuten 53 seconden open; #1197 6 uur 21 minuten 56 seconden.
Die verschillen verhinderen een algemene conclusie dat PR-wachttijd verwaarloosbaar is.

Van de 37 PR's met een complete bestandsdelta veranderen 28 `src/` en 9 niet.
Een productie-PR kan een component, binding, correctie of recompositie leveren.
Een test- of brononderzoek-PR kan zelfstandige veiligheidswinst hebben.
Een percentage ontwikkeltijd is **UNKNOWN**. Bij de vier genoemde crop-blokken
zijn er samen 1494 src-toevoegingen op 24739 totale toevoegingen, circa 6,0%.
Dit toont omvangrijke niet-productiedelta's, niet dat 94% van de tijd overhead is.

Herhaalde kwalificatie is daadwerkelijk zichtbaar, maar niet overal onnodig.
#1206 verandert lifecycle/schema en croptransactie; #1207 activeert emergence,
roots en growth; #1209 verandert dagafronding. Hun actuele eigenaar- en
compositiegates zijn nodig. Als deze afhankelijke delen eerst op één branch tot
een stabiel resultaat waren ontwikkeld, hadden tussentests kunnen blijven en
had het aantal volledige admissioncycli mogelijk kunnen dalen. Dat is een
counterfactual, geen gemeten besparing. Onafhankelijke kwalificatie van ieder
nieuw fysisch gedrag blijft nodig binnen de uiteindelijke cyclus.

## Reconstructie van de uitvoeringsketens

| Werkstroom | Bron en scope | Implementatie/checkpoint/gerichte tests | Brede kwalificatie/preservation | Admission en coverage |
| --- | --- | --- | --- | --- |
| MC-CROP01 | #1152/#1154 bronnode en geometrie; #1157 geaccepteerde hydrothermische snapshot; #1160 parameteridentiteit; #1171 TAV-volgorde; #1176 byte-extractor | #1192 weather-binding, #1193 twee intervallen, #1194 twee dagen; #1197/#1204 echte file-weather-applicatie; #1206 task2/3, #1207 emergence/root/growth, #1209 dayend. Verscheidene checkpointcommits en O0/O2-records | #1160 owner/science/F-CI herstel; #1206/07/09 volledige moving F-CI, PPA en 24 hoogste frostconfiguraties/144 vergelijkingen. Bronblobs en raw logs vastgelegd | Merge plus exact-blobreconciliatie; PR1072 ontvangt begrensde crop-receipts. Geen volledige crop-promotie |
| MC-IRR01 | #1126 geïsoleerde gekwalificeerde eigenaar; #1195 recompositie. Letterlijke TCS/DCS/TASK4-bron | #1198 atomaire SSDI-route, #1199 sensor/depth/restart; #1200 haalbare real-depth diagnose en storage-arithmetic; #1201 saltmodifier, #1203 echte salt-state, #1205 allocationbinding | O0/O2 sourcecases en echte Richards-events; eigenaar- en moving F-CI. Tiny impulses eerst beperkt; real-depth/salt/allocation later afzonderlijk gekwalificeerd | #1195 vijf fullcaps; opvolgers begrensde vooruitgang, elf fullcaps blijven actief. Handoff master, geen automatische fullcap-promotie |
| MC-ROOT01 | #1123 bestaande root/oxygen/potential-shadow-eigenaren gerecomposeerd; #1127 letterlijk Feddes | 61 zichtbare commits #1123; joint gates #1125. Geometry, stress, owner en runtime worden samen getest | #1124 whole-src-guard-probleem; #1125 gezamenlijke crop/root plus B19/MICRO preservation; #1127 O0/O2 | #1123 en #1125 overlappen. Geen twee onafhankelijke fysieke resultaten tellen; actuele eigenaarrecords bepalen de claim |
| MC-HEAT01 | #1196 source-bound vier thermische opties; Snow bewust buiten productie | Drie productieblobs; process/runtime O0/O2, default-oracle, checkpoint en canonical recompositie | 55 terminale Actions volgens eigenaarrecord; EB-I25-baselinefout opnieuw op juiste worktree gecontroleerd; central moving gate opnieuw, 14 frozen jobs geërfd | Vier capabilities admitted volgens canonical `MC_HEAT01_STATUS.json`; master #1072 noemt ze nog ACTIVE. Documentaire achterstand, geen ontbrekende thermal-implementatie |
| Drainage/frost | #1056 oorspronkelijke analytische drainage/frost-bronnen en afgebakende rootless Reference-scope | Equation/tangent/composition en volledige trajectories; fresh-family-processen na memory exhaustion | Fijne onafhankelijke referenties, mass, retry/restart, SALT4/root en exact canonical preservation; negatieve en partial logs behouden | Begrensd admitted. Gewone frost-off, multilevel en coupling blijven eigen werk |
| MC-NUT01/MC-SOL01 | #1117 geconsolideerde B1.11 owner/binding-route, aquifer fail-closed | 131 bestanden, 342 commits; niet-complete opgehaalde commitgeschiedenis; reactive/age/water/Soil-N/crop-N | PR beschrijft incomplete exact source/O0/O2/restart-admission. Geen compleet terminal admissionbewijs onderzocht | Nog open draft. Grootte alleen garandeert geen afsluiting; geen vreemde eigenaar overnemen |
| F-CI/integratie/master | #1202 echte conductivitybron; #1124/25 exacte opvolgerpreservation; #58 integratiecarrier; #1072 capabilitycensus | Exact sourcepins, failure attribution, recompositie, recovery | Historische fixed-ref jobs naast moving-current gate; inhoudelijk verschillende autoriteiten | #58 blijft draft naar main. Mastercensus niet exhaustief bewezen. Canonical ontvangst en ledger kunnen uiteenlopen |

Relevante actuele navigatie: [PROJECT-CONTROL](../development/SWAP5_PROJECT_CONTROL.md),
[execution-protocol](../development/workstream-execution-protocol.md),
[workstreams](../development/workstreams.md),
[invarianten](../architecture/invariants.md),
[Status-A traceability](../status-a/TRACEABILITY.md) en
[post-Status-A](../status-a/POST_STATUS_A_CURRENT_STATE.md).
De uitvoeringsrecords zijn `MC_CROP01_DAYEND_PRODUCTION_STATUS.json`,
`MC_CROP01_ROOTED_WEATHER_PRODUCTION_STATUS.json`, `MC_IRR01_STATUS.json`,
`MC_IRR01_ONSET_DIAGNOSIS_20261011.json`,
`MC_ROOT01_UNIFIED_QUALIFICATION_CHECKPOINT_20261008.json` en
`MC_HEAT01_STATUS.json` onder `integration/audits/` op de genoemde canonical.
PR-samenvattingen zijn gebruikt als claim; actuele records en exact gepind bewijs
bepalen de geldige begrenzing. Een PR-merge alleen bewijst geen volledige kwalificatie.

## Aantoonbare kosten en echte blokkades

Drie F-CI-runs zijn met jobdatums en daadwerkelijke workflowpostimages onderzocht:

| Run | Eerste jobvertraging (s) | Moving-jobduur (s) | Som 14 frozen jobduren (s) |
| --- | ---: | ---: | ---: |
| [37908979248](https://github.com/abhedwig-cell/SWAP5/actions/runs/37908979248) | 267 | 433 | 312 |
| [37915213624](https://github.com/abhedwig-cell/SWAP5/actions/runs/37915213624) | 27 | 493 | 316 |
| [37943443221](https://github.com/abhedwig-cell/SWAP5/actions/runs/37943443221) | 1877 | 820 | 341 |

De 14 frozen jobdefinities zijn inhoudelijk identiek na YAML-parsing, SHA256
`60cf6c1a2531067b861fa7bfa5c41257fbb4045e035f87049f2b92eb53a8f1b8`.
Ze rekenen op vaste historische checkoutrefs, niet op de kandidaatcode. Samen
zijn dat 42 historische jobuitvoeringen en 969 seconden job-walltijd. Bij behoud
van de eerste uitvoering zijn 28 herhaalde uitvoeringen/657 seconden een
**potentieel herbruikbare** hoeveelheid. Dit is geen gemeten kalenderversnelling,
runnerrekening of CPU-besparing. Omgevingsidentiteit en admissionbeleid moeten
eveneens reuse toestaan. Warmte geeft al een praktisch precedent: frozen bewijs
uit run38121781430 is geërfd, de moving gate is opnieuw uitgevoerd.

Het controlbestand in de PR1209 dayend-archive meet 1894,410 seconden voor full
moving F-CI en 201,033 seconden voor PPA preservation. Deze begonnen vrijwel
tegelijk, dus geen optelling tot circa 35 minuten kalenderduur. Full F-CI duurde
hier circa 31,6 minuten vóór de PR-openstelling. De logs bevatten overlappende
eigenaarsuites; zonder complete dependency- en argumentvergelijking is niet
aangetoond welke individuele oproepen veilig weg kunnen.

`.github/workflows/fci-canonical.yml` heeft een ongefilterde canonical push-trigger;
PR-triggers omvatten alle `src`, `tests` en `tools`. De historische jobs staan vóór
de moving gate in de dependencyketen. #1196 rapporteert 55 terminale workflows,
26 success en 29 failure. Dat is aantoonbare uitvoerings-/adjudicatiebelasting,
geen bewijs van 29 nieuwe fysische regressies. Smalle triggers zijn al onderzocht
in PROJECT-CONTROL; het effect op queues is niet gemeten.

Echte risico's verklaren een deel van de opsplitsing. #1160 moest grididentiteit
aan geaccepteerde F-KT-state binden; een nodecounter of caller-ID volstond niet.
#1200 vond zowel een fysisch ongeschikte 3cm-fixture als subtraction cancellation
in gedeelde HeadCalc-arithmetic. Die correctie vereiste HY-regie en echte
storage-/solverpreservation. #1196 houdt Snow/thermal tegen wegens state-layout
en eventvolgorde. De cropfasebeslissing vereist ochtendinitialisatie terwijl
de geaccepteerde EOD-state al dezelfde tijd draagt en F-KT positieve intervallen
eist. MODFLOW-drainage vraagt afzonderlijke phreatic/lower-face, tangent, donor- en
mass-ownershipautoriteit. Deze blokkades verdwijnen niet door PR's groter te maken.

## Werkpakketgrootte en Work-herstel

| Keten | Noodzakelijke scheiding | Waarschijnlijk combineerbaar | Risico bij bundeling |
| --- | --- | --- | --- |
| #1152/54/57/60 | Onafhankelijke bronnode, geometry, snapshot en eigenaarcertificaat zijn verschillende bewijsclaims; gedeelde kernelbeslissing expliciet | Binnen één ontwikkelingstak, aparte focused gates, één bron/owner-readinessresultaat na gedeelde autoriteit; #1153/58 afsluitmetadata samen verwerken | Ongeteste stateless mapping als fysieke forcing behandelen |
| #1192/93/94 | Weatheridentity, intervalacceptatie en dagovergang moeten alle worden getest | Eén resultaat “twee echte weatherdagen door productie”; drie testfasen hoeven geen drie admissioncycli te zijn | Een selectorpass verwarren met positief fysisch endpoint |
| #1204/06/07/09 | Task2/schema, emergence en dayend hebben eigen negatieve en restartcriteria | Task2 → emergence → growth → final flush als één jaarlijkse weather-productieroute zodra interfaces vastliggen | Grote foutzoekruimte en gedeelde runtimeconflicten; checkpoints/focused tests behouden |
| #1198/99/1200/01/03/05 | Realistische fysische envelope, HY arithmetic en solute state vereisen verschillende eigenaars | Sensor+root DCS/modifier/allocation testen op gemeenschappelijke eventroute, na HY/SOL-acceptatie | Numerieke of zoutblokkade verbergen in één enorme irrigation-PR |
| #1196 | Snow/layout apart houden | Vier thermische opties samen was gerechtvaardigd | Snow stilzwijgend als vijfde capability meetellen |
| #1117 | Eigenaar-/watercarrier-/restartgrenzen behouden | Consolidatie bestaat al; eerst terminale gates afsluiten | Nog groter maken vergroot overlap en diagnostische onzekerheid |

Het aantal technisch minimaal benodigde implementatiestappen is **UNKNOWN**:
de geschiedenis toont gekozen stappen, geen bewezen minimum. Voor de drie
weather-PR's zijn wel drie concrete wijzigingssets zichtbaar en een plausibel
gemeenschappelijk resultaat. Capabilitycensus blijft de auditstructuur;
het fysische resultaat wordt de uitvoeringsstructuur. Geen arbitrair minimum
capabilities per PR.

AGENTS en execution-protocol bevatten al bounded recovery, source discovery,
dependency-aware inheritance en “checkpoint is geen stopconditie”. Er is dus
geen bewijs dat opnieuw hetzelfde lange protocol nodig is. Er bestaat wel
ambiguïteit met “small slices” in workstreams: kleine reviewbare veranderingen
zijn verenigbaar met een groter functioneel einddoel, maar worden makkelijk als
kleine sessie-eindpunten gelezen. Dat verdient verduidelijking.

Commitgeschiedenis en recovery-records tonen herstelde compile-/fixturefouten,
oude whole-src-guards en malformed remote brontransport (#1200). Ze tonen niet
hoe vaak een sessie dezelfde bron las of door de gebruiker met “go” moest worden
hervat. Herhaalde bronnenzoeken, toolcallaantallen en overtreding van stopregels
zijn daarom **UNKNOWN** als projectmeting. #1171 bronvolgordeonderzoek en #1176
byte-extractie hebben inhoudelijke veiligheidswinst; ze zijn geen bewezen verspilling.
Een opgeslagen archivepad en hash maken brede rediscovery op de volgende sessie
wel vermijdbaar. De eerdere small/medium-throughput-closeout van 6 oktober is
gelezen: die behandelt capabilitytriage, niet deze 38-PR-procesanalyse. Er is
geen gelijkwaardig onderzoek gevonden in development/audits en de gerichte
GitHub-zoekopdrachten; dat is geen bewijs van afwezigheid op iedere historische branch.

## De vijf grootste verbeterkansen

1. **Functionele bundeling:** houd de afhankelijkheidsketen op één branch tot een
   echte uitvoerbare route klaar is. Verwachte winst: minder full/admissioncycli;
   grootte van de winst UNKNOWN. Houd afzonderlijke owneroracles en rollbackchecks.
2. **Frozen en moving bewijs scheiden:** erf alleen bewezen ongewijzigde historische
   jobs; kwalificeer actuele gewijzigde fysica opnieuw. Identieke frozen definities
   en warmteprecedent maken dit concreet. Automatische reuse eerst in shadow mode.
3. **Resume vanaf eigenaarcheckpoint en intersecterende delta:** bestaande sourcehash,
   paths en next_action hergebruiken. Besparing in zoektijd UNKNOWN. Geen nieuw register.
4. **Gedeelde besluiten vóór afhankelijke productie:** HY/grid, cropfase, Snow/layout
   en drainage/MODFLOW als afzonderlijke readinessgrenzen afhandelen. Vermijdt
   speculatieve opvolgers; ownershipwachttijd blijft afzonderlijk meetbaar.
5. **Admissionreceipt en ledger in dezelfde afsluitronde:** traceerbare mergeverificatie
   behouden, documentaire successors bundelen. De master heeft 243 rijen, gerecomputeerd
   95 ADMITTED/108 ACTIVE/14 SUPERSEDED/2 REJECTED/20 NOT_APPLICABLE/4 QUALIFICATION_ONLY,
   maar warmte toont dat deze telling geen actuele afwezigheidstelling is.
   De incomplete broncensus en eigenaarclaims blijven zichtbaar.

## Onderzochte PR's

`src`-aantallen zijn changes tegen de PR-base, niet unieke capabilities of arbeid.
Open/niet-gemerged is geen vertraagde admission als de PR een onderzoeks- of
integratiecarrier is. Zie het onderzoeksbestand voor exacte SHAs en tijdvelden.

| PR | Werkstroom / resultaat | Status | src bestanden / alle | Toevoegingen src / alle | Open tot merge (s) | Commits volledig |
| --- | --- | --- | ---: | ---: | ---: | --- |
| [#58](https://github.com/abhedwig-cell/SWAP5/pull/58) | F-CI canonical integration: F-CI02-F-CI13 | OPEN | UNKNOWN / 5657 | UNKNOWN / 2865087 | UNKNOWN | nee |
| [#1056](https://github.com/abhedwig-cell/SWAP5/pull/1056) | PPA-WU05B12: admit qualified analytic drainage with normal and low-air frost | MERGED | 4 / 25 | 99 / 2664 | 40.0 | ja |
| [#1072](https://github.com/abhedwig-cell/SWAP5/pull/1072) | SWAP431 master coverage: source census and reconciled checkpoint (in progress) | OPEN | 2 / 83 | 102 / 74500 | UNKNOWN | ja |
| [#1117](https://github.com/abhedwig-cell/SWAP5/pull/1117) | QUAL: consolidated SW431 NUT/SOL binding postimage and exact-source gate | OPEN | 44 / 131 | 5347 / 11157 | UNKNOWN | nee |
| [#1123](https://github.com/abhedwig-cell/SWAP5/pull/1123) | MC-ROOT01: unified SWRD2/SWRD3 and potential-shadow canonical recomposition | MERGED | 17 / 38 | 1987 / 3202 | 17402.0 | ja |
| [#1124](https://github.com/abhedwig-cell/SWAP5/pull/1124) | F-CI: bound B19/MICRO source-tree preservation for crop/root successor | CLOSED_UNMERGED | 0 / 1 | 0 / 38 | UNKNOWN | ja |
| [#1125](https://github.com/abhedwig-cell/SWAP5/pull/1125) | QUAL: joint crop/root plus F-CI B19/MICRO preservation gate | MERGED | 17 / 42 | 1986 / 3534 | 15218.0 | ja |
| [#1126](https://github.com/abhedwig-cell/SWAP5/pull/1126) | MC-IRR01: isolated irrigation owner admission candidate on canonical | CLOSED_UNMERGED | 11 / 30 | 1469 / 3244 | UNKNOWN | ja |
| [#1127](https://github.com/abhedwig-cell/SWAP5/pull/1127) | MC-ROOT01: qualify empirical Feddes oxygen against admitted canonical | MERGED | 1 / 7 | 47 / 269 | 817.0 | ja |
| [#1152](https://github.com/abhedwig-cell/SWAP5/pull/1152) | MC-CROP01: reconcile accepted grid identity for physical sowing forcing | MERGED | 1 / 6 | 35 / 206 | 1863.0 | ja |
| [#1153](https://github.com/abhedwig-cell/SWAP5/pull/1153) | MC-CROP01: record B1.11 sowing node canonical admission | MERGED | 0 / 1 | 0 / 37 | 14.0 | ja |
| [#1154](https://github.com/abhedwig-cell/SWAP5/pull/1154) | MC-CROP01: validate B110 grid geometry before B1.11 sowing node selection | MERGED | 1 / 5 | 39 / 108 | 615.0 | ja |
| [#1157](https://github.com/abhedwig-cell/SWAP5/pull/1157) | MC-CROP01: atomically sample accepted F-KT hydraulic head and soil heat | MERGED | 1 / 5 | 78 / 193 | 732.0 | ja |
| [#1158](https://github.com/abhedwig-cell/SWAP5/pull/1158) | MC-CROP01: record admitted atomic F-KT hydrothermal view | MERGED | 0 / 1 | 0 / 34 | 12.0 | ja |
| [#1159](https://github.com/abhedwig-cell/SWAP5/pull/1159) | MC-CROP01: define transaction-owned B110 grid identity before physical forcing | CLOSED_UNMERGED | 0 / 2 | 0 / 78 | UNKNOWN | ja |
| [#1160](https://github.com/abhedwig-cell/SWAP5/pull/1160) | MC-CROP01: bind immutable B110 parameter grid to F-KT committed state | MERGED | 4 / 16 | 426 / 1094 | 17213.0 | ja |
| [#1171](https://github.com/abhedwig-cell/SWAP5/pull/1171) | MC-CROP01: verify exact B1.11 external tav writer and daystart ordering | MERGED | 0 / 1 | 0 / 47 | 9.0 | ja |
| [#1176](https://github.com/abhedwig-cell/SWAP5/pull/1176) | MC-CROP01: fail-closed byte-exact B1.11 meteorology source extractor | MERGED | 0 / 3 | 0 / 162 | 440.0 | ja |
| [#1183](https://github.com/abhedwig-cell/SWAP5/pull/1183) | MC-CROP01: tighten physical crop event forcing lifecycle admission (unqualified checkpoint) | MERGED | 1 / 5 | 16 / 74 | 1197.0 | ja |
| [#1187](https://github.com/abhedwig-cell/SWAP5/pull/1187) | MC-CROP01: physical F-KT commit of weather-derived crop event with restart | MERGED | 0 / 4 | 0 / 27 | 500.0 | ja |
| [#1190](https://github.com/abhedwig-cell/SWAP5/pull/1190) | MC-CROP01: common weather-day Tmin/Tmax/TAV read boundary | MERGED | 1 / 3 | 8 / 19 | 392.0 | ja |
| [#1192](https://github.com/abhedwig-cell/SWAP5/pull/1192) | MC-CROP01: weather-bound PPA-WU03 hydrological forcing opt-in | MERGED | 1 / 5 | 24 / 82 | 1386.0 | ja |
| [#1193](https://github.com/abhedwig-cell/SWAP5/pull/1193) | MC-CROP01: use same weather record for two committed PPA-WU01 intervals | MERGED | 0 / 2 | 0 / 16 | 1036.0 | ja |
| [#1194](https://github.com/abhedwig-cell/SWAP5/pull/1194) | MC-CROP01: continuous PPA hydrology across two registered weather days | MERGED | 0 / 3 | 0 / 65 | 575.0 | ja |
| [#1195](https://github.com/abhedwig-cell/SWAP5/pull/1195) | MC-IRR01: admit qualified irrigation management owner | MERGED | 11 / 31 | 1469 / 3304 | 894.0 | ja |
| [#1196](https://github.com/abhedwig-cell/SWAP5/pull/1196) | MC-HEAT01: migrate thermal analytical and boundary modes | MERGED | 3 / 10 | 252 / 1595 | 12387.0 | ja |
| [#1197](https://github.com/abhedwig-cell/SWAP5/pull/1197) | MC-CROP01: authentic daily weather in physical production and prior-accepted F-KT daystart | MERGED | 3 / 15 | 391 / 1232 | 22916.0 | ja |
| [#1198](https://github.com/abhedwig-cell/SWAP5/pull/1198) | MC-IRR01: literal SSDI availability and atomic management Richards binding | MERGED | 5 / 17 | 287 / 1280 | 646.0 | ja |
| [#1199](https://github.com/abhedwig-cell/SWAP5/pull/1199) | MC-IRR01: source DCS1 sensor composition and in-flight physical/event continuation | MERGED | 2 / 9 | 175 / 1107 | 846.0 | ja |
| [#1200](https://github.com/abhedwig-cell/SWAP5/pull/1200) | MC-IRR01: qualify real-depth irrigation through stable shared storage arithmetic | MERGED | 1 / 11 | 4 / 1821 | 1728.0 | ja |
| [#1201](https://github.com/abhedwig-cell/SWAP5/pull/1201) | MC-IRR01: common root salt modifier and realistic event preservation | MERGED | 2 / 15 | 48 / 1261 | 23.0 | ja |
| [#1202](https://github.com/abhedwig-cell/SWAP5/pull/1202) | F-CI93: actual trial-start fixed conductivity for non-M1 headed Task2 | MERGED | 1 / 14 | 10 / 3130 | 307.0 | ja |
| [#1203](https://github.com/abhedwig-cell/SWAP5/pull/1203) | MC-IRR01: accepted physical salt concentration in production irrigation | MERGED | 1 / 11 | 202 / 1568 | 31.0 | ja |
| [#1204](https://github.com/abhedwig-cell/SWAP5/pull/1204) | MC-CROP01: authentic daily weather and accepted F-KT soil in production crop daystart | MERGED | 4 / 30 | 844 / 11145 | 93.0 | ja |
| [#1205](https://github.com/abhedwig-cell/SWAP5/pull/1205) | MC-IRR01 persistent external allocation: physical restart and current canonical qualification | MERGED | 1 / 12 | 230 / 1462 | 20.0 | ja |
| [#1206](https://github.com/abhedwig-cell/SWAP5/pull/1206) | MC-CROP01: qualified historical task2/task3 in actual weather/F-KT production | MERGED | 5 / 21 | 161 / 5772 | 246.0 | ja |
| [#1207](https://github.com/abhedwig-cell/SWAP5/pull/1207) | MC-CROP01: production delayed emergence and authentic-weather rooted growth | MERGED | 4 / 17 | 375 / 4554 | 47.0 | ja |
| [#1209](https://github.com/abhedwig-cell/SWAP5/pull/1209) | MC-CROP01: actual current-weather day-end growth and final-day completion | MERGED | 1 / 14 | 114 / 3268 | 33.0 | ja |
