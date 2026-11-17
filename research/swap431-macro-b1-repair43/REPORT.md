# REPAIR43: minimaal contactherstel bij dezelfde poging 357

**Lokaal geslaagd met O0 en O2.** Het CONTRACT42-herstel behoudt het werkelijk onverzadigde, met macroporiewater in contact staande wanddeel van de GWL-cel. De oude eindige uitstroomsprong is vervangen door gewone variatie die met de proefafstand afneemt. Dezelfde oorspronkelijke grote poging357 accepteert nu ongereduceerd in vijf iteraties, met een verse V1-eindcertificatie. Hostcommit, procesgeheugen en onafhankelijke waterinventaris slagen.

De nieuwe fysische wijziging is uitsluitend het eerder afgebakende contactherstel en de bijbehorende native geschiedenisbijwerking. De overige proceswetten, solvervoorwaarden, toleranties, MAXIT, dt- en reductieregels zijn behouden. Er is geen algemene B1- of canonieke toelating.

## Basis en vastgelegde scope

Basis is CONTRACT42 `e6358b26a7fff51caa1aae54b7f3afc8669ae43d`. De eerste bronvastlegging vóór builds en modelroutes is `4b0d9752f`; de definitieve geschiedenisaanvulling is vóór de laatste builds en routes vastgelegd in `2fd75e206`.

Dezelfde oorspronkelijke native checkpoint t1900=35797 en dezelfde eigen kandidaatprefix leveren exact de356 voorafgaande commits en de oorspronkelijke pogingcontext357: t1900=35797,487000006880, dt=0,001000001146167051 dag. De onderzoeksflag voor het contactherstel staat in de aanloop uit en wordt pas in deze context aangezet. De correctie is dus niet reeds op een nieuwe gehele aanloop getoetst. B0, B1.12, canonieke SWAP5 en de no-macrorelease zijn niet gewijzigd.

De geselecteerde fysische basis en oorspronkelijke afwijzing zijn vastgelegd in [CONTRACT42](../swap431-macro-b1-contract42/ADJUDICATION.md). `SOURCE_CHANGES.patch`, `CONTRACT.json` en `HISTORY_ALIGNMENT.patch` beschrijven de implementatie en afbakening.

## Minimale implementatie

In de standaard swmbf=1-tak omvat ABSORPTION nu ook de GWL-cel als haar matrixkop negatief is. De bestaande perched-uitsluiting blijft gelden. Voor deze nieuwe cel wordt de overlap bepaald van de geometrisch onverzadigde wand met de wand die werkelijk met macroporiewater is gevuld:

`contactfactor = onverzadigde watercontactlengte / oorspronkelijke watercontactlengte`.

De berekening gebruikt uitsluitend de bestaande celranden, GWL en macroporiewaterstand; er is geen instelbare meng- of gladheidsparameter. De bestaande sorptie- en Darcy-bedragen worden met dezelfde factor vermenigvuldigd vóór hun bestaande maximumselectie. Een al aanwezige gedeeltelijke macroporie-wetfractie blijft behouden; de normalisatie voorkomt dubbel wegen. Dit is in de proeven afzonderlijk gecontroleerd voor domein3 met gedeeltelijk natte wand en domein4 met volledig natte wand.

Bij een niet-negatieve matrixkop blijft de nieuwe ABSORPTION-cel uitgesloten en de ongewijzigde SATFLOW-route verantwoordelijk. De rate- en bestaande lokale afgeleidenlus hebben hetzelfde bereik. De lokale afgeleiden gebruiken de gewogen werkelijke flux; de extra niet-lokale GWL-afgeleide van de contactfactor is niet toegevoegd. Er wordt geen exacte volledige Jacobiaan geclaimd. De bestaande 50/51-/cel-51-correctie blijft in deze vijf Jacobianen inactief en haar voorwaarden zijn niet verruimd.

De native geschiedenisbijwerking gebruikt hetzelfde toegelaten GWL-celbereik en dezelfde geometrische contactregel. De oorspronkelijke keuze voor de eindgeometrie en bijgewerkte natte wandfractie blijft daarbij behouden. De theoretische sorptiereferentie krijgt de contactweging; de bestaande eventklok telt bij een voortgezet event precies één gebruikte dt door. De resetregels en het overige geschiedenismodel blijven behouden.

## Sprongtoets op het oorspronkelijke punt

De herstelde stap kan vóór iteratie10 convergeren. Daarom worden de sprongproeven uitgevoerd op de onveranderde, bewaarde CONTRACT42-toestand van oorspronkelijke poging357/iteratie10. Deze fysische snapshot en numerieke cache zijn op identiteit gecontroleerd; `FROZEN_INPUTS.json` bindt de hashes. Een buitenste transactie herstelt daarna de werkelijke prehead-hostcontext bytegelijk.

Per route zijn er negen extra echte MACRORATE(1)-evaluaties: basis, drie paren rond -60, de exacte grens en herhaalde basis. Elke proef begint uit dezelfde herstelde toestand.

| GWL-afstand (cm) | Oude D4-ratesprong (cm/dag) | Hersteld tweezijdig verschil (cm/dag) |
|---|---:|---:|
| 0.0001 | 0.0565371106115 | 4.74309159006e-06 |
| 1e-06 | 0.0565361619314 | 4.74313894203e-08 |
| 1e-08 | 0.0565361524456 | 4.74314337806e-10 |

Het resterende verschil neemt met de afstand af en wijst niet op de oude eindige sprong. Op GWL=-60 zelf is de domein4-rate 0,056536152349761726 cm/dag en sluit zij op beide proefzijden aan. De afzonderlijke verzadigde rate op node47 blijft nul in deze negatieve-kopproeven; er wordt geen tweede SATFLOW-bijdrage bijgeteld. De beneden-grens- en basiscontroles zijn exact gelijk aan CONTRACT42.

Tien innerlijke herstelcontroles per route bewijzen bytegelijkheid van de20.347.880-byte SENSE23-scope en3.247.712-byte numerieke/observatiecache, met herstel van de erkende IEEE-vlaggen en opgeslagen IEEE-status. De buitenste host-/cache-snapshots en de gedumpte oorspronkelijke inventory/context/ledger zijn eveneens vóór en na de probes exact gelijk.

## Convergentie, hostcommit en water

| Grootheid | Definitief O0 | Definitief O2 |
|---|---:|---:|
| Procesduur (s) | 2,686024 | 2,094836 |
| Iteraties | 5 | 5 |
| Vectorberekeningen | 7 | 7 |
| Extra lijnzoekproeven | 0 | 0 |
| Verse V1-certificaties | 1 | 1 |
| Grootste residu | 3,0218933588788133e-7 | gelijk |
| Somresidu | -3,016126045539233e-7 | gelijk |
| Fluxfactor | 1 | 1 |

De oude poging faalde na dertig iteraties met grootste residu0,02571625908888784. De herstelde grote dt blijft0,001000001146167051 dag en wordt meteen geaccepteerd. De originele host committeert t1900=35797,488000008023; de volgende dt blijft volgens de bestaande regeling dezelfde waarde. Er is geen kleinere retry of geforceerde afwijzing gebruikt.

De onafhankelijke target-waterinventarisfout is -3,0161284450894166e-10 cm bij bestaande grens1,000001146167051e-8 cm. De vijf domeinbalansen sluiten tot maximaal9,22e-17 cm; de primitieve ledgerincrementen komen overeen met de gecommitteerde fluxintegralen. De ledger blijft tijdens de proef en vóór hostcommit gelijk aan de beginledger.

Na hostcommit loopt het domein3-event door: de klok stijgt van0,005000005730835255 naar0,006000006877002306 dag, exact één gebruikte dt. De sorptiviteit blijft behouden en de theoretische referentie neemt toe met3,226599104566574e-8. De native eindgeometrie geeft daarvoor contactfactor0,6362967095764742; een onafhankelijke reconstructie van de bestaande gewogen geschiedenisformule sluit binnen1e-16. Het beëindigde Darcy-event in domein4 heeft klok, referentie en sorptiviteit nul.

## Bewaarde voorlopige uitvoering en grenzen

De eerste O0/O2-uitvoering bevestigde al dezelfde sprongreparatie, vijf iteraties en sluitende waterinventaris. Controle van de gecommitteerde toestand liet echter zien dat het oorspronkelijke MacroState-geschiedenisbereik het domein3-geheugen alsnog wiste. Die voorlopige versie is daarom niet als volledig gekwalificeerd gehandhaafd. Bronnen, oorspronkelijke identiteiten, werkelijke binaries en uitvoer blijven bewaard in `preliminary_source/`, `PRELIMINARY_*`, `PRELIMINARY_RESULT.json` en de native PRELIMINARY-buildclosure.

Na de noodzakelijke geschiedenisaanvulling zijn uitsluitend dezelfde twee O0/O2-routes opnieuw uitgevoerd. Solveruitvoer, geaccepteerde fysische proefkop, budgetregels, waterinventaris en ledger zijn exact gelijk aan de voorlopige versie; het native sorptiegeheugen is nu correct voortgezet. Totaal vier routes, alle normaal, ongecensureerd en onder2,69 seconden per route. De harde twintigsecondenlimiet en bestaande interne zestiensecondenstop zijn behouden. Er zijn geen andere contexten, perioden of campagnes gestart.

Alle definitieve numerieke tekstuitvoer en snapshots zijn O0/O2-bytegelijk buiten rekentijdvelden. Het resultaat geldt alleen voor deze oorspronkelijke context en de gerichte sprongproeven. Nieuwe volledige eigen aanloop, periodebalans, herstart, overige perched-/krimpgeometrieën en een algemene exacte contact-Jacobiaan zijn niet gekwalificeerd. Omdat de definitieve stap direct accepteert, is echte afwijzing/rollback/directe kleinere retry voor deze nieuwe fysische patch evenmin gekwalificeerd.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; geen officiële promotie. `assess_repair43.py` analyseert uitsluitend opgeslagen uitvoer. `REPAIR43_EVIDENCE.zip` bewaart bron, ruwe uitvoer en beide werkelijke buildversies; `EVIDENCE.json` bindt checkpoint en SHA-256. De sealer verifieert alle opgenomen bestanden streamend tegen het manifest.
