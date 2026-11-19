# FOLLOW67 — BOUNDED_UNRESOLVED

Het eigen geaccepteerde CAUSE66-checkpoint is daadwerkelijk in een vers proces
gelezen en vergeleken met een continue uitvoering op O0/O2. De overdracht van
de vastgelegde native context en ledger is exact; beide uitvoeringen geven
dezelfde eerste gekoppelde residuals en dezelfde twee echte afwijzingen.
Er is geen nieuwe geaccepteerde vervolgstap. Daarom blijft de gevraagde
geaccepteerde voortzetting **BOUNDED_UNRESOLVED**; de checkpointoverdracht en
de overeenkomende negatieve vervolgroute zijn wel begrensd ondersteund.

## RECONCILE en contract

Basis: CAUSE66 `96f1a1f7b4325d4933f32235bbd724767dad808f`, single-step
QUALIFIED_BOUNDED_COUPLED_ACCEPTANCE, zonder algemene B1-/restartpromotie.
De bestaande phase1/V6 native+ledger-overdracht van NATIVE55 is hergebruikt.
Canonical na fetch is `ef5010a83e83f879254af534bf0dd9cfcdbf3a85`: afzonderlijke
no-macro kalenderintegratie. Geen productiebron of canonical gewijzigd.

Voorregistratie `aa166dbd5` ligt vóór compilatie en alle vier modelprocessen.
Bron-/bouwcheckpoint `c201dbd76` ligt vóór de eerste uitvoering. Eén volgende
hoststap, geen nieuwe contextselectie of dt-zoektocht; CONT en verse RESTART
op O0 en O2. Hard20s, bestaande interne16s en totaal4pogingen per proces.
Geen modelroute buiten deze vier. Alle vier zijn normaal en ongecensureerd.

De numerieke COMBINED63-correctie blijft exact beperkt tot haar bestaande
t1900=35797.290431125148. Haar eligibility is niet uitgebreid naar de nieuwe
tijd om convergentie af te dwingen. Alleen de diagnostische CAUSE66-contextgate
en de begrenzing van de reeds causale onderrandrefresh benoemen aanvullend
het aangevraagde nieuwe beginpunt35797.290441125151. De refresh is nog steeds
de oorspronkelijke BoundBottom na de werkelijke TimeControl(5)-verkleining.
Fysica, criteria, Jacobiaan, MAXIT30/60, backtracking en tijdregeling zijn gelijk.

## QUALIFY — werkelijk eigen checkpoint

CONT begint uit dezelfde oorspronkelijke D2-native oorsprong als CAUSE66,
doorloopt exact dezelfde grotere weigering en kleine geaccepteerde retry, en
schrijft na SoilWater(3), Integral(3) en TimeControl(3) `cut67.end`. Hij keert
vervolgens terug naar de ongewijzigde hoofdloop. Dit is een echt doorlopende
uitvoering; de vervolgstate wordt niet opnieuw uit een gewenste snapshot gezet.

De eerste geaccepteerde stap, beide oorspronkelijke solverrecords, budget en
toestand reproduceren CAUSE66 exact. Het nieuwe cutbestand is139128bytes,
SHA256 `d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7`.
Dat is exact het eerder gekwalificeerde CAUSE66-eindpacket. Inventory/context/
ledger zijn vóór en na het schrijven byte-identiek. De eigen writer verandert
de getoetste fysieke en geïntegreerde toestand dus niet.

RESTART leest precies dit CONT-bestand in een nieuw proces. Native tijd is
35797.290441125151 en de opgeslagen, door TimeControl voorgestelde volgende
dt is2e-5dag. De oude REJECT64-harnessinjectie is verwijderd: er wordt geen dt
uit een externe environmentvariabele over de native voorstelwaarde geschreven.
Alle andere caseinputs zijn de hash-gebonden CAUSE66-inputs, met dezelfde
native-restart-control deck. Er zijn geen nieuwe fysieke native velden of een
nieuwe serializer geïntroduceerd.

De fresh installatiecontext en ledger zijn byte-identiek aan de CONT-cut.
Vóór de eerste vervolg-HeadCalc zijn ook alle geregistreerde native velden,
de opnieuw door SoilWaterStateVar/MacroStateVar opgeslagen oorsprongsbuffers
en de ledger exact gelijk. Initiale werkvelden verschillen wel: macro_in_vert,
macro_exchange, macro_rapid, matrix_exchange, matrix_vertical, boundary_rates
en twee eventflags. Die bestaande verschillen zijn behouden en niet tot nieuwe
native fysieke state gepromoveerd. De volgende volledige gekoppelde evaluatie
geeft ondanks die werkveldverschillen exact dezelfde112-node residual.

## ANALYZE — dezelfde afwijzingen op O0/O2

| Vervolgpoging | dt [dag] | Uitgevoerde iteraties | Fmax [cm/dag] | somF [cm/dag] | Knoop |
|---|---:|---:|---:|---:|---:|
|normaal voorstel|2e-5|30|2.5860524544712715e-3|1.0665405317951893e-2|52|
|normale dtmin-retry|1e-5|60|2.5351081763289596e-3|1.0151382521751356e-2|52|

Deze getallen zijn exact gelijk tussen CONT en RESTART, op beide optimalisaties.
Fortran-DO-tellers zijn31/61; er zijn30/60 werkelijke iteraties. Geen van beide
pogingen bereikt de bestaande lokale1e-6 en totale1e-5cm/dag-criteria; er is
geen voorlopige acceptatie en dus geen afsluitende fresh acceptatiecontrole.
De eerste volledige vector_F(1) per poging is wel berekend en exact vergeleken.

Beide complete solverrecords, de native begin-/retourcontext per poging,
opgeslagen oorsprong en ledger zijn byte-identiek. De pogingjournalen zijn
gelijk na normalisatie van de bedoelde processpecifieke poging-/staptellers
en weglaten van wandtijd. De nieuwe gekoppelde boundarycontexts en beide
eerste volledige residualvectoren zijn exact gelijk. CONT draagt de twee
eerdere CAUSE66-pogingen mee als1/2, de vervolgpogingen zijn3/4; in RESTART
zijn dat1/2. De fysieke vergelijking gebruikt de werkelijk overeenkomstige
pogingen, niet het ruwe proceslokale nummer als tijdidentiteit.

Wandtijden: O0CONT4.107s, O0RESTART2.662s, O2CONT3.106s, O2RESTART2.046s.
CONT bevat ook de eerdere geaccepteerde CAUSE66-stap. O0/O2 geven alle84/51
vergeleken niet-timingtekstfiles byte-identiek, plus gelijke pogingvelden
buiten wandtijd en hetzelfde cutpacket. RESULT.json benoemt ieder bestand.

Na de tweede afwijzing vraagt de oorspronkelijke solver IDecMpRat1 aan.
FrReduQ blijft1: numerieke fluxreductie is nog niet uitgevoerd. De bestaande
harness herstelt de fysieke toestand en stopt op
NATIVE55_FOLLOW_SCALED_REQUEST_EXCLUDED. Er wordt niet alsnog een gereduceerd
probleem geaccepteerd of verder geïntegreerd. Dezelfde uitsluitingsregel geldt
voor beide routes; geen tolerantie of guard is aangepast.

De90 vervolg-Jac63-calls vallen allemaal met code−1 buiten de ongewijzigde
exacte tijdgate. Er is nul actieve COMBINED63-aanvulling op deze nieuwe tijd.
Dat is een concrete grens van de kandidaat, geen bewijs dat alleen uitbreiding
van de gate convergentie zou opleveren. Zo'n tegenproef of toelating is hier
niet uitgevoerd. De bestaande successen op de vorige tijd worden niet geërfd
als bewijs voor een nieuwe numerieke context.

## Rollback, tijd en water

Na beide negatieve routes is de vastgelegde native context onderling exact,
en vergeleken met de eigen cut slechts numeriek verschillend in dt/dtold.
De fysieke h/theta, pond, macrovoorraden en persistent geregistreerde geschiedenis
zijn terug op oorsprong. De beginledger is byte-identiek aan de eindledger.
Tijd blijft35797.290441125151: nul geaccepteerde tijdvooruitgang na de cut,
nul nieuwe hostcommit en nul ledgerintegratie. CONT heeft alleen zijn ene oude
CAUSE66-budgetrecord; RESTART heeft geen nieuw budget-/inventoryrecord.

Er is daarom geen nieuwe geaccepteerde waterinventaris of periodebalans te
kwalificeren. De geërfde CAUSE66-waterinventaris blijft geldig voor de voorafgaande
cut-stap, maar wordt niet als nieuwe vervolg-PASS geteld. `follow67.end` bestaat
in geen van de vier routes.

In de bredere eindinventory verschilt alleen matrix_vertical tussen CONT en
RESTART:113 werkwaarden, max0.40963479371070916cm/dag. CONT heeft de uitvoer-
werkvector van zijn vorige geaccepteerde stap, de verse route niet. SoilWater(3),
die de nieuwe verticale fluxoutput zou berekenen, is na deze afwijzing niet
uitgevoerd. Dit is expliciet uitgezonderd van complete werkgeheugenbyte-identiteit;
alle solvervelden, gerestaureerde named native state en ledger zijn gelijk.

## PERSIST / CLOSE

Besluit **BOUNDED_UNRESOLVED** voor een geaccepteerde eigen-checkpointvoortzetting.
Begrensd positief: eigen packetproductie zonder gemeten toestandseffect, daadwerkelijke
verse phase1-overdracht en dezelfde ongereduceerde weigering/retry/rollback op O0/O2.
Er is in deze geselecteerde route geen aanwijzing dat ontbrekende native fysieke
state de afwijkende voortzetting veroorzaakt: de daadwerkelijke solveruitkomsten
wijken juist niet af. Algemene restartcorrectheid is daarmee niet bewezen.

Geen reparatie is gerechtvaardigd door deze gematchte negatieve uitkomst. Geen
physics-/criteriumwijziging, verbreding van Jacobiaan-eligibility of langere
campagne uitgevoerd. De afzonderlijke volgende onderzoeksvraag is eventuele
kwalificatie van de bestaande gekoppelde numerieke correctie op precies deze
nieuwe toestand; deze unit promoveert dat niet automatisch. De eerdere CAUSE66-
single-stepkwalificatie blijft nauw begrensd geldig. Geen productiepromotie.

Compiler GNU Fortran16.2.0 MSYS2 Rev4. Bronnen, daadwerkelijke buildcommando's,
opties, timings en executable-/objecthashes zijn vastgelegd. De objecten voor
Jac63, constitutieve macroprocessen, native09, TimeControl, BoundBottom en
Integral zijn hash-identiek aan CAUSE66. Alleen de drie onderzoeks-harness- en
observerbestanden zijn herbouwd. De twee gewijzigde modulefiles betreffen de
bijbehorende bron-/private harnessinformatie, geen nieuwe native fysieke layout.
IEEE_DENORMAL wordt zoals in CAUSE66 gemeld en ongewijzigd bewaard.

FOLLOW67_RAW.zip bewaart alle vier volledige raw cases inclusief originele
inputs, cut/nativebinaries, geweigerde solvers, exacte compilerbronbytes,
daadwerkelijke executables en builddelta. manifest.json koppelt logische namen
aan lossless SHA256-blobs; identieke inhoud wordt eenmaal opgeslagen. Geërfde
ongewijzigde objecten blijven eenmaal in CAUSE66/REJECT64-archieven. EVIDENCE.json
bindt de keten. Onafhankelijk uitpakken en zero-model herbeoordelen geeft
byte-identiek RESULT.json; VERIFICATION.json legt dit vast.

Herstel: start de eigen storage-lifecycle en alloceer een tempmap. Sparse-checkout
FOLLOW67 en CAUSE66 op deze branch. Pak de eigen capsule uit via unpack67.py
en CAUSE66 via diens unpack66.py. Geef de nieuwe data/ en geërfde CAUSE66-data/
aan assess67.py. Deze beoordeling start nul modellen. Voor nieuwe modelruns
eerst de exacte geërfde objectclosure en BUILD_DELTA herstellen of de bewaarde
executables gebruiken; oude lokale paden zijn geen blijvende autoriteit.

De vier-route-unit is gesloten met een open acceptatiegate, niet een nog lopende
proef. Na push en controle van centrale Gitobjects worden uitsluitend eigen
reproduceerbare werkkopieën en de schone eigen checkout via cleanup.py afgehandeld;
buildretentie volgt het gedeelde beleid. Andere chats en hun resources blijven
ongemoeid. Wetenschappelijk bewijs en herstelidentiteit blijven centraal in Git.
