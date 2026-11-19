# CAUSE66 — QUALIFIED_BOUNDED_COUPLED_ACCEPTANCE

Het verschil uit COUPLED65 is causaal geïsoleerd en voor de ene vastgelegde D2-
timestep hersteld. Na een echte grotere afwijzing gebruikte de interne retry
nog de diepe grondwaterstand van het grotere tijdseindpunt. Een onafhankelijke
directe kleinere stap berekende die onderrandwaarde op het kleinere eindpunt.
Dat verschil verklaart het eerste residualverschil volledig. Het is geen nieuwe
verklaring van de reeds vastgestelde flunsatok(3)-macrofreeze.

De begrensde onderzoeksreparatie roept na TimeControl(5) de oorspronkelijke
BoundBottom opnieuw aan. Op O0 en O2 zijn daarna de eerste volledige residual,
alle drie lineaire retrysystemen, geaccepteerde toestand, ledger, waterbudget en
native eindpacket exact gelijk aan de onafhankelijke directe kleinere stap.
Dit kwalificeert de getoetste timestep en effectieve rollback/retry, geen algemene
B1-referentie, volledige geheugenbyte-identiteit of productiepromotie.

## RECONCILE en begrenzing

Baseline: COUPLED65 `3db3836f3ad887605a265be25acbf4ceebfd4dc9`.
Geërfde compiler-/objectclosure: REJECT64
`95a61203d345ccbf2c8f5851c37a0bb138a00835`, SHA256-gebonden archief in
EVIDENCE.json. Canonical is ongewijzigd. AGENTS, opslaglifecycle en bestaande
COUPLED65-status/bronnen/bewijscapsule zijn opnieuw gelezen.

Gelijktijdig liep SELECT65 op een andere chat/branch. Zijn latere eindstatus
`f4520283e` registreert NO_TRUE_V_REJECTION_IN_EIGHT_BOUNDED_D2_PROPOSALS,
met ongewijzigde REJECT64-bronnen/binaries. Dat levert geen geschikt nieuw
V-afwijzingsbewijs en verandert deze bron-/inputbasis niet. Zijn werkcheckout,
resources en experimenten zijn niet gebruikt of gewijzigd. Deze unit zoekt
geen nieuw tijdstapvoorstel. RECONCILIATION.json bindt de geraadpleegde refs.

Dezelfde NATIVE55 D2-begintoestand is gebruikt: t1900=35797.290431125148,
native SHA256 `59988fe0728bc51006085bbc957afc16ddf50b23a5cbb644228716dff743748e`.
CHAIN gebruikt de bestaande grotere dt2.0951312035156963e-5 dag en de
daadwerkelijke interne retrydt1e-5. DIRECT begint uit hetzelfde native bestand
op die daadwerkelijk verkleinde dt. Geen hoofden, historische geheugens,
bodem-/macroparameters, forcingtabellen of toleranties zijn afgestemd.

Contractcommit `5cbdd915e` ligt vóór alle modellen. Observer/bouwcheckpoint
`956200415` ligt vóór de eerste vier proeven. Causaal bewijs en reparatiebron
zijn vóór de hertoets vastgelegd in `3d81787e0`. Totaal acht modelprocessen:
vier causale controles en vier reparatiekwalificaties. Alle normaal, ongecensureerd,
0.620–1.667s, binnen hard20s en bestaande interne16s/4pogingen. Geen extra
model na de acht geselecteerde routes. Geen volledige CI of481-daagse run.

## QUALIFY — eerste afwijking en causaal mechanisme

De oorspronkelijke host in REJECT64/swap_native.f90 roept BoundBottom aan vóór
de interne retrylus. Na weigering herstelt hij SoilWaterStateVar/MacroStateVar,
roept TimeControl(5) aan en herhaalt de lus zonder BoundBottom te verversen.
BoundBottom interpoleert voor SWBOTB3/SW3=2 de aquiferdrukhoogte deepgw op
t1900+dt. HeadCalc gebruikt deepgw daarna in iedere impliciete Cauchy-evaluatie.
deepgw ontbreekt in de bestaande native-contextdump: gelijke dumps waren dus
geen bewijs van dezelfde trialforcing. deepgw is hier afgeleid rekenwerk per
poging en hoeft geen nieuw persistent native-stateveld te worden.

De werkelijk gebruikte oorspronkelijke BoundBottom-bron is byte-identiek aan
`3db3836f3:reference/swap-4.3.1/b1_11_frost_source/SWAP/boundbottom.f90`.
BOUNDARY_SOURCE_VERIFICATION.json bindt bron en objecten. Hercompilatie op
O0/O2 met dezelfde compiler, flags en oorspronkelijke bronbestandsnaam geeft
precies de geërfde objectbytes. Een eerste controle vanaf een verplaatste
bronbestandsnaam gaf een ander object: Fortran neemt die naam op in runtime-
I/O-metadata. Die negatieve controle, de objecten en de daaropvolgende exacte
controle zijn behouden; er is geen geërfd modelobject vervangen door de probe.

De nieuwe observer meldt alleen de onderrandcontext bij HeadCalc-ingang en na
de eerste volledige vector_F. Zonder ingreep reproduceert hij alle57/43
vergeleken niet-timingtekstbestanden van COUPLED65-CHAIN/DIRECT, de pogingvelden
buiten wandtijd en het native packet exact. Instrumentatie-invloed is daarmee
getoetst vóór de causale interventies.

| Grootheid bij eerste retry-evaluatie | CHAIN oud | DIRECT |
|---|---:|---:|
|deepgw [cm]|-70.432361661165487|-70.432352900120904|
|deepgw-verschil CHAIN−DIRECT [cm]|-8.761044583138755e-6| |
|Cauchy-noemer disnod/kmean+rimlay [dag]|10.25|10.25|

De eerste volledige112-node residual verschilt uitsluitend op knoop112.
De exacte bronrelatie is qbot=−(h112+z112−deepgw)/noemer en F112 bevat−qbot.
Daarom is ΔF112=−Δdeepgw/noemer. Gemeten8.547360568905704e-7 cm/dag,
voorspeld8.547360568915859e-7: afwijking−1.02e-18 cm/dag.

Vervolgens zijn twee enkelvoudige causale interventies uitgevoerd:

1. CHAIN krijgt vóór de kleinere HeadCalc uitsluitend deepgw opnieuw uit de
   oorspronkelijke afgen op t+actueledt. Eerste residual, solver, volledige
   commit, ledger, budget en packet worden exact die van DIRECT.
2. DIRECT krijgt uitsluitend deepgw uit dezelfde afgen op het geregistreerde
   grotere eindpunt. Hij reproduceert exact de oude CHAIN-retry, inclusief
   dezelfde eerste residual en hetzelfde afwijkende native packet.

De macro-rate-/eventresten zijn in beide interventies ongemoeid gelaten.
Daarmee zijn die verschillen niet de oorzaak van het geselecteerde eindverschil.
Dit is een lokale causale uitspraak, geen universele onschadelijkheid van alle
lokale SAVEs of eventflags. CAUSAL_RESULT.json bewaart beide kruisingen,
observerpreservatie en de onafhankelijke vergelijking met de Cauchy-formule.

## REPAIR — afgeleide trialforcing verversen

REPAIR.patch voegt aan de onderzoeks-host na de bestaande TimeControl(5) één
aanroep toe naar een begrensde wrapper die de oorspronkelijke BoundBottom
aanroept. De wrapper vereist de exacte D2-tijd, echte dtmin-retry, native
RESTART, SWMACRO1/SWBOTB3/implicit/table/resvert0/SW4=0. Buiten deze
geregistreerde envelop stopt hij, wanneer ingeschakeld. De oorspronkelijke
interpolatie, weerstand en onderrandformules zijn ongewijzigd.

De reparatie verandert de tijdstapverkleining niet. Hij zorgt dat de afgeleide
forcing bij de werkelijk gekozen trialdt hoort. Ook qbot_nonfrozen en andere
door de oorspronkelijke provider beheerde onderrandwerkwaarden worden regulier
ververst. Geen gefabriceerde rollback of directe kopie van een gewenste oplossing.
DIRECT heeft geen weigering en voert de nieuwe refresh niet uit.

Alle overige fysica, V1 fresh eindcontrole, COMBINED63-correcties, bestaande
MAXIT30/60, backtracking, massaguard, reductieregels en native layout blijven
gelijk. Er is geen nieuwe solver of Jacobiaan gemaakt. BUILD_DELTA bevat alleen
headcalc.o (observer), swap.o (hostrefresh) en swap_exchange.mod. Van die module
verschilt uitsluitend de bronbestandsnaamheader; de volledige declaratiebody
is byte-identiek (MODULE_INTERFACE_VERIFICATION.json). Geen gedeelde interface
of fysieke/native-statevelden zijn toegevoegd.

## ANALYZE — O0/O2 hertoets

| Route | Processen | Grotere poging | Kleinere geaccepteerde stap |
|---|---:|---|---|
|O0 CHAIN|1|echte30-iteratieweigering, ongewijzigd|3 iteraties, één fresh controle|
|O0 DIRECT|1|niet uitgevoerd|3 iteraties, één fresh controle|
|O2 CHAIN|1|echte30-iteratieweigering, ongewijzigd|3 iteraties, één fresh controle|
|O2 DIRECT|1|niet uitgevoerd|3 iteraties, één fresh controle|

De grotere afwijzing blijft Fmax2.1198336748706748e-3/som8.414477305576075e-3
cm/dag. Zijn solverrecord en pogingvelden buiten timing zijn exact gelijk
aan de oude ongerepareerde CHAIN. Er is één boundaryrefresh per CHAIN en nul
per DIRECT. De werkelijke grotere afwijzing gebruikt de W-aanvulling; de retry
gebruikt W/V/V. Een grotere V-actieve afwijzing is hier niet getoetst.

Vóór de retry zijn alle geregistreerde native-contextvelden op oorsprong,
behalve de bedoelde dt/fldtmin. De ledger is exact ongewijzigd. Tussen CHAIN-
retry en DIRECT zijn opgeslagen macro-oorsprong en named native context exact
gelijk. Sommige pre-evaluatie-rate-/eventwerkvelden blijven ongelijk; ze zijn
niet uit het gewenste eindresultaat gekopieerd. De volledige eerste verse
evaluatie en alle drie werkelijk gebruikte lineaire systemen zijn nu exact
gelijk: dezelfde A, r, oplossing en beide updatevectorparen, met uitsluitend
de bedoelde verschillende poging-/sequence-identiteiten in de headers.

Na de fresh acceptatie zijn alle solvervelden, h/theta, macrovelden inclusief
eventresultaten, named native context, hostcommit, ledger, budget en native
packet exact gelijk tussen CHAIN en DIRECT. O0/O2 geven ook onderling exact
dezelfde60/45 vergeleken niet-timingtekstbestanden en packets. RESULT.json
noemt de bestanden en assertions. De directe oplossing is ongewijzigd tegenover
COUPLED65: de reparatie brengt de interne retry naar deze onafhankelijk bepaalde
oplossing, niet naar het historische CHAIN-resultaat.

Alle vier geaccepteerde stappen hebben:

| Grootheid | Waarde |
|---|---:|
|dt [dag]|1e-5|
|fresh Fmax [cm/dag]|3.0444564034712296e-8|
|fresh somF [cm/dag]|2.0918046662162138e-7|
|IDecMpRat / FrReduQ|0 / 1|
|hostcommits / ledgerintegraties|1 / 1|
|matrixvoorraaddelta [cm]|-2.2257545273197916e-6|
|macrocompartimentdelta [cm]|-6.358460167625287e-7|
|pond-/canopydelta [cm]|0 / 0|
|externe netto-integratie [cm]|-2.8616026359441764e-6|
|onafhankelijke waterinventarisfout [cm]|2.0918618560915032e-12|
|bestaande geïntegreerde limiet [cm]|1e-10|

Alle112 nodale residuen liggen onder1e-6 en de som onder1e-5 cm/dag.
De inventaris is onafhankelijk uit theta/dz/matrixfractie en alle macro-
compartimenten berekend, met expliciete pond/canopy en originele externe
hostfluxen. Macro_sat wordt niet dubbel geteld. Grootste afzonderlijke
domeinfout5.38e-17cm; inventaris minus somF*dt kleiner dan2e-15cm.
Geen numerieke fluxreductie en geen integratie van de geweigerde poging.

Het eigen follow.end is139128bytes, op alle vier routes SHA256
`d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7`.
Alle processen eindigen op dezelfde geaccepteerde t1900=35797.290441125151.
De eigen eindcheckpoint is niet opnieuw als begin van een volgend modelproces
gelezen; dat blijft een afzonderlijke restartgate.

## PERSIST / CLOSE — reikwijdte en herstel

Besluit **QUALIFIED_BOUNDED_COUPLED_ACCEPTANCE**, uitsluitend voor deze vaste
D2-begintoestand, echte W-actieve grotere afwijzing, normale kleinere retry met
ververste impliciete onderrandforcing en onafhankelijke directe herberekening
op O0/O2. De effectief geaccepteerde toestand/ownership, fresh residuals,
waterinventaris en rollback/retry-equivalentie zijn binnen dit contract ondersteund.

Niet gekwalificeerd: afwijzing met actieve V-correctie, iedere pre-evaluatie-
scratchbyte identiek, alle andere boundarymodi, algemene restart, eigen follow-
restart, langere periode, alle oorspronkelijke macroporiënfysica of B1 als
wetenschappelijke migratiereferentie. Geen automatische productiepromotie.
Voor migratie is de afgeleide trialforcing nu een concreet ownershipcontract:
verkleining van dt vereist actuele forcing op het nieuwe trialeindpunt.
De vroegere COUPLED65-inconclusiviteit is voor deze oorzaak en vergelijking
opgelost; de overige B1-uitsluitingen blijven zichtbaar.

Compiler: GNU Fortran16.2.0 MSYS2 Rev4. Nieuwe geselecteerde bestanden zijn
gebouwd met dezelfde O0/O2-vlaggen en gehashte bestaande objectclosure;
bouwcommando's, timings, bron-/object-/executablehashes zijn versioned.
IEEE_DENORMAL is zoals in de baseline op alle routes gemeld en behouden.
Er zijn geen gewijzigde floating-point exceptioninstellingen.

CAUSE66_RAW.zip bewaart alle acht ruwe routes, volledige caseinputs, native
start/eindpackets, actual executables, gewijzigde objecten en de negatieve
verplaatste-bronnaamcontrole. SHA256-manifestblobs dedupliceren identieke
inhoud; geërfde ongewijzigde buildobjecten blijven eenmaal in het centrale
REJECT64-archief. EVIDENCE.json bindt beide. De capsule is onafhankelijk
uitgepakt; beide zero-model beoordelaars geven byte-identiek CAUSAL_RESULT.json
en RESULT.json. VERIFICATION.json registreert deze herstelcontrole.

Herstel: start de eigen storage-lifecycle en alloceer een tempmap; sparse-checkout
CAUSE66 en COUPLED65 op deze branch. Gebruik unpack66.py voor de nieuwe capsule
en COUPLED65/unpack_coupled65.py voor de baseline. Geef de nieuwe datamap en
baseline-datamap aan assess_cause66.py; geef de nieuwe datamap aan
assess_repair66.py. Dat start nul modellen. Voor werkelijk nieuwe runs eerst de
gehashte REJECT64-closure herstellen, daarna BUILD_DELTA overlay of bewaarde
executables gebruiken. De lokale oude werkpaden zijn geen blijvende autoriteit.

De unit is na de acht processen gesloten; er is geen open draaiende proef.
Na push en centrale objectcontrole worden uitsluitend eigen gealloceerde
werkkopieën en de schone eigen checkout via de gedeelde cleanup.py vrijgegeven.
Andere chats en hun resources worden niet gefinisht. Ruwe wetenschappelijke
evidence en herstelidentiteit blijven centraal in Git behouden.
