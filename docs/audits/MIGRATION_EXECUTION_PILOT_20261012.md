# Gecontroleerde proef: volledige SWRAIN=1-route

**Status: Proposed; niet geïmplementeerd of gekwalificeerd.** Rechtstreeks
uitvoerbare vervolgopdracht, met verplichte live-readinesscontrole. Analysebasis:
canonical `cdd0c02c0b3a5b7f35c00c7138bd6898a4eb98fc`, master PR1072
`a0ea55bf3c53237be9ee9c9efa1d560d8c234f64`. Gebruik het
[uitvoeringsmodel](MIGRATION_EXECUTION_MODEL_20261012.md).

## Keuze, eigenaar en scope

Realiseer **SW431-MET-RAIN1** als één end-to-end functioneel werkpakket binnen
**MC-MET01**, met bestaande PPA-WU03 meteorologie/forcing- en RT bootstrapautoriteit.
Geen nieuwe persoonlijke eigenaar wordt verondersteld. De master noemt RAINTB/
day-of-year pulse-resolving nog ontbrekend; de huidige file-weather-bootstrap
gebruikt `rain*0.1` als uniforme dagrate. Het common-forcing-contract accepteert
een reeds opgeloste intervalrate. Dat geeft een begrensde, plausibele route.
Er is in de actuele open PR-lijst geen expliciete MC-MET01/RAINTB-kandidaat gevonden.
Dat is geen toestemming om een later opgedoken eigenaar te passeren.

Crop harvest/rotation is niet gekozen: de
[fasebeslissing](../science/MC_CROP01_HARVEST_ROTATION_PHASE_DECISION.md) is nog
onbeslist. Ook Snow/thermal, drainage/MODFLOW en NUT/SOL zijn geen vrije proefscope.

De volledige proefuitkomst is: authentieke dagelijkse neerslag plus getypeerde
RAINTB geven de historische midnight-pulse; echte Full Richards-hydrologie
verwerkt pulse-on/pulse-off en de volgende dag zonder verloren of dubbele
neerslag, ook na afwijzing, retry en restart. Gebruik één root-free AIR/no-snow/
default-MVG bottom7-profiel als eerste fysische envelope. Geen PMtraditional,
detailed meteorology, irrigation, croptransition of gekoppelde MODFLOW uitbreiding.
Een fullcap-admission vraagt dat de bevoegde owner de geteste getypeerde inputscope
voldoende vindt. Anders blijft de capability ACTIVE met een bounded receipt.

Deze ene capability is groot genoeg: broninterpolatie, leap-calendar, pulseplanning,
authentieke invoer, actuele fysische forcing, mass, eventgrens en continuation
moeten gezamenlijk werken. Het is geen losse pure selectorproef.

## Eerste actie en dependencygrens

Lees AGENTS, bestaand protocol, PROJECT-CONTROL, MC-MET01-masterrij, actuele open
PR's en crop-file-weather/dayend-recovery. Pin nieuw canonical. Zoek alleen relevante
delta sinds deze analyse. Controleer bij PR700/reconciliation dat geen seasonal-rain
implementatie of broncorrectie de claim heeft ingehaald. Persisteer scope en
next_action in het bestaande MC-MET01-eigenaarrecord of, als dat ontbreekt, de
gebruikelijke owning auditstatus. Dat is geen nieuw projectbreed register.

Reconcile met PPA-WU03/RT/cropowner de smalle opt-in-forcingseam vóór wijziging van
de bootstrap. Voorkeur: een pure bronresolver en externe segmentplanning via
het bestaande resolved-forcingpad. Wijzig `run_weather_interval` alleen als de
bestaande gezamenlijke autoriteit een backward-compatible opt-in hiervoor accepteert.
Geen tweede weather/stateowner of ongecontroleerde callerweather toevoegen.
De baseline-uniforme route moet ongewijzigd blijven.

Held fixed: kernel positieve intervallen, `HeadCalc`/providers, temporal/masscriteria,
trial/accept/retry/rollback, accepted-state-publicatie, opaque joint continuation,
crop/root, irrigation, solute, Snow/frost en MODFLOW-contracten. Toegestaan:
MC-MET01 pure typed RAINTBresolver, minimale forcingbinding onder genoemde owner,
eigen tests/oracle/evidence. Als feitelijke endpointkwalificatie een HY/state/
restart-contractwijziging vereist, registreer het concrete gatefailure en geef
het aan die owner. Geen stilzwijgende solverrepair en geen arbitrale tolerantie.
De bekende INT12-C-negative fixtures bewijzen niet dat deze proef onmogelijk is;
ze verbieden wel het vervangen van echte acceptance door gesimuleerde resultaten.

## Bron, uitvoering en gates

Bron: bestaande `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`,
member `SWAP/MOD_meteo.f90`, SHA256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.
De onderzochte lijnen 643-644, 657-686 en 694-696 converteren mm naar cm,
selecteren natte dagen, bepalen leap day-of-year, evalueren AFGEN en vormen
`duration=min(1,depth/intensity)` met `rate=depth/duration`.
Gebruik ook daadwerkelijke AFGEN-, `vsmall`-, afsluit-/zoek- en intervalintegratiebron;
deze regels alleen bewijzen geen volledig endpointgedrag. Maak een onafhankelijke
uitvoerbare bronoracle, niet alleen dezelfde nieuwe formule in de test.

1. Ontwikkel resolver en schedule met focused O0/O2. Test zero/below/at/above
   `vsmall`, tabelknopen en interpolatie, leap/nonleap, jaarsprong, puls korter
   dan dag en dagcap. Exact bronsemantiek voor geldige inputs; invalid/NaN/zero
   intensity en ongeldige tabel fail-closed volgens expliciet ownercontract.
2. Composeer dezelfde authentieke weatherrecord en getypeerde intensity tot
   pulse-on/off. Partitioneer requested intervallen op echte schedulegrenzen;
   tel neerslag slechts eenmaal. Restart halverwege pulse en precies op einde
   houdt identity, voortgang en aangenomen fysische state coherent.
3. Kwalificeer echte productie op minstens drie weatherdagen met nat/droog/nat
   plus meerdere onafhankelijke intensityprofielen. Test beginsel “dezelfde
   dagdiepte, andere intensiteit” als forcingwitness; claim geen verplichte
   verschillende eindstate voor elk willekeurig profiel. Selecteer en motiveer
   een fysisch haalbare fixture, zonder numerieke drempels te veranderen.
4. Demonstreer daadwerkelijk pulse-einde, aanhoudende hydrologie na einde,
   geaccepteerde vervolgdagen, forced rejection/retry, incomplete interval zonder
   publicatie, exactly-once en continue/restored vectoridentiteit op O0/O2.
   Zelfstandige interpolatie- of nominale endpointtests sluiten dit niet af.
5. Bij stabiele kandidaat: onafhankelijke sourcepolicy en productieowner,
   toepasselijke common-forcing/PPA, default file-weather/crop preservation,
   relevante Full Richards/current F-CI en alle door dependency-impact vereiste
   frost/root/heat/irrigation/solute gates. De huidige eigenaaracceptatie, massbudgetten,
   certified trajectories en referentietoleranties blijven exact. Bewijsreuse
   alleen volgens het model; tijdens deze eerste proef geen nieuw testselectorbeleid.
6. Reconcile live head en overlaps, kwalificeer getroffen mergetreedelta,
   verifieer admissionblobs en geef één begrensde PR/receipt plus masterupdate.
   Houd onafhankelijke ownergates zichtbaar in die ene admissioncyclus.

## Meting en eerlijke vergelijking

Gebruik bestaande checkpoint/status en runnercontrol JSON/logs. Voeg alleen aan
het proefrecord een korte eventlijst toe: UTC begin/einde, stage, tested SHA,
runner, inputs/flags, resultaat, reden voor rerun of inheritance. Voor aktive
sessies start/stop apart vastleggen; ontbrekende perioden blijven UNKNOWN.
Runnerduur is geen actieve arbeid. Een interveniërende menselijke inhoudsbeslissing
is iets anders dan een “go” om een veilige volgende stap te laten doorgaan.

Historische procesbaseline: #1192/#1193/#1194 vormen samen weatherownerbinding,
twee geaccepteerde intervallen en twee dagen. Dit zijn drie afzonderlijke PR's,
met open-tot-mergeduren 1386/1036/575s, maar geen drie onafhankelijke resultaten.
Broninterpolatie en pulse-on/off ontbreken daar; de RAINTB-proef is dus complexer.
Hun start ligt uiterlijk bij eerste zichtbare commit #1192
2026-10-10T21:09:42Z; laatste merge #1194 2026-10-11T05:12:25Z.
Dit kalenderwindow bevat onbekende pauzes; actieve tijd en Work-interventies UNKNOWN.
Gebruik daarnaast #1207/#1209 als complexere recovery/preservationvergelijking,
niet als gelijkwaardige snelheidscijfers. Reconstrueer voor iedere vergelijkingsrun
de gedekte scope en alle relevante runinputs vóór een duplicaat wordt geteld.

| Metriek | Definitie / acceptatie |
| --- | --- |
| Doorlooptijd per resultaat | Eerste readinesscheckpoint → verified canonical receipt; ook build/qualification/admission apart. Geen oorzakelijk procent sneller bij ongelijke scope |
| Herhaald onderzoek | Dezelfde bronhash + dezelfde vraag opnieuw onderzocht zonder dependencydelta; nieuwe vraag niet meetellen. Historisch UNKNOWN waar logs ontbreken |
| Herhaalde gates | Zelfde complete inputclosure/omgeving/argumenten + claim opnieuw; count en job-wall apart. Invalidation-reruns gerechtvaardigd apart |
| Work-interventies | Aantal expliciete gebruikershervattingen na checkpoint; inhoudelijke besluiten en runtimeonderbrekingen apart. Historisch UNKNOWN |
| Historische capabilities | Hoogstens één MET-RAIN1 fullcap na complete owner-admission; bounded route kan echte vooruitgang met countdelta 0 zijn |
| Integratieherstel | Failing merge/requalification, oorzaak en gemeten herstelinterval; geen arbeidsminuten uit commitgaps |
| Fouten/regressies | Alle gevonden fouten, vindfase en impact; ongezien risico niet afleiden uit alleen “0 gevonden” |

Wetenschappelijke acceptatie: alle noodzakelijke gates terminal PASS of door de
bevoegde autoriteit expliciet begrensd adjudicated baseline debt; geen nieuwe
ongeadresseerde regressie, tolerantieaanpassing of ownerdrift. Een fout die pas
in broad qualification wordt ontdekt blijft een proefbevinding, ook als gerepareerd.

Procesacceptatie: één coherent resultaat met één admissioncyclus, checkpoints
zonder nodeloze userstop, traceerbaar bewijs voor elke reuse, en geen onverklaarde
identieke full rerun. Minder PR's alleen is geen succes. Rapporteer absolute
kosten, complexiteitsverschillen en UNKNOWN. Een tijdsbesparing blijft
**INCONCLUSIVE** zolang een scope-equivalente baseline ontbreekt. Bij succesvol
functioneel resultaat maar onbekende tijd is het resultaat “haalbaar proces,
snelheid niet bewezen”; geen projectbrede rollout op één negatieve/kleine proef.

Deze analyse implementeert de proef niet. De volgende Work-sessie kan direct
met de readinessactie beginnen; een actuele ownership- of scienceblokkade stopt
alleen afhankelijke productie en wordt met exacte next_action vastgelegd.

## Readinesscontrole bij overdracht, 12 oktober 2026

Canonical en PR-overlap zijn opnieuw gecontroleerd op dezelfde baseline
`cdd0c02c0b3a5b7f35c00c7138bd6898a4eb98fc`; er is geen nieuwe relevante delta.
De actuele registry bevat REGIE en PPA als bestaande verantwoordelijke rollen,
maar geen afzonderlijke MC-MET01-entry. MC-MET01 is hier de workunit uit de
mastercoverage, geen bewijs dat een vrije productie-eigenaar al is toegewezen.
Gebruik de bestaande REGIE/PPA-routing om deze begrensde proefscope te beleggen;
maak geen tweede ownershipregister.

De concrete ingang heeft een aanvullende grens. In
`mod_fmr_production_application_bootstrap.f90` weigert
`run_standalone_with_forcing` de uitvoering bij actieve file-weather als
`weather_interval_active` niet door de interne bewaakte route is gezet.
`run_weather_interval` stelt de dagrate momenteel zelf in op `rain*0.1`.
De optionele weatherguard in het common-forcing-adapter controleert identity
en intervaldekking; hij levert zelf geen RAINTB-resolver of productieschedule.
De aanwezigheid van een algemene resolved-forcing-ingang bewijst dus niet
dat een externe planner de authentieke file-weather-route al kan bedienen.

Voor de gekozen file-weather-proef is de concrete voorkeursroute een
owner-geaccepteerde opt-in-resolver/binding **binnen de bewaakte
weather-intervalroute**, met positieve segmenten tot pulse-einde en daarna
zero-rain-segmenten. Behoud recordidentity, begin-day ownership, dagafronding,
accepted-prefix-publicatie en bestaande joint continuation. Zet geen private
active-flag van buitenaf, schakel geen provenanceguard uit en presenteer een
losse standalone typed-forcing-test niet als file-weather-integratie.
Een extern alternatief is alleen geldig als de owning autoriteit vooraf een
volledige equivalente authenticatie/publicatie/continuationroute vastlegt.

Readinessstatus: **READY_FOR_BOUNDED_OWNER_CONTRACT; NOT_IMPLEMENTATION_READY**.
De eerstvolgende beslissende actie is bij REGIE/PPA met de bestaande RT/cropowner
de opt-in-ingang, segment-publicatie en schedule-reconstructie uit record plus
onveranderde RAINTB te begrenzen. Leg ook vast hoe veranderde tableidentity bij
restart wordt afgewezen en hoe een voltooide prefix na latere failure blijft
bestaan. Daarna kan de volgende productieopdracht de hierboven omschreven
complete proef bouwen en meten. Bronautoriteit is al beschikbaar; dit is een
concrete gedeelde application-contractgrens, geen ontbrekende-sourceblokker.
