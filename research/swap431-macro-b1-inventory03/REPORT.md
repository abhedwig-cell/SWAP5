# SWAP431-MACRO-B1-INVENTORY03

**De eerste gereduceerde V1-stap doorstaat een onafhankelijke volledige waterinventaris. Mijn advies blijft: eis ongereduceerde gekoppelde convergentie voor de beoogde fysische B1-referentie.** Een conservatieve gereduceerde berekening is niet noodzakelijk de oplossing van het ongereduceerde procesmodel. V1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`; er is geen officiële referentie gewijzigd of toegelaten.

## Onderzoeksbasis en scope

Basis: definitieve STATE02-commit `e7c5b44ebe3efd4f1a84f073803f9eab3b2cfa12`. Nieuwe branch `research/swap431-macro-b1-inventory03-20261113`. De live remote had bij aanvang geen opvolger van STATE02; canonical bleef `e157e65ff36305d8661f7c8afb9577bad6b6ecd0`. ADR-0005 blijft leidend: een verbeterde numerieke onderzoeksvariant is geen automatisch gekwalificeerde B1-snapshot.

De gebruiker vroeg verder te gaan en vervolgens advies over het referentiecontract. Deze ronde behandelt de onafhankelijke inventaris, die voor beide beleidskeuzen relevant is. Het advies is vastgelegd als **voorstel**, niet als een reeds genomen besluit om de reductiewet te veranderen. Geen nieuwe ongereduceerde solvervariant, droge-contextzoektocht, restartclaim of migratie is gestart.

Geselecteerd is uitsluitend de eerste al bekende gereduceerde geaccepteerde stap: `t1900=35796.9513533331`, `dt=0.0001414213562373095 d`, gebruikte `IDecMpRat=1`. Beide native O0/O2-routes bereiken deze context vanuit dezelfde oorspronkelijke Andelst-invoer en stoppen na de echte geaccepteerde `SoilWater(3)`-overgang. De gemeten operatorvectoren komen exact overeen met STATE02 `rate1`; dit is geen nieuw scenario.

## Onafhankelijke methode

De probes bewaren de begin-, trial- en geaccepteerde toestand, de vijf domeinvoorraden en compartimentvoorraden, de oppervlaktelaag, de oorspronkelijke sink/source/roots, domeinuitwisseling, macro-invoer, snelle drainage en externe randfluxen. `headcalc_inventory.f90` registreert bovendien het gecertificeerde residu, drukhoogten en de daadwerkelijk gebruikte geleidbaarheden. `soilwater_inventory.f90` voert daarna de echte originele geaccepteerde overgang uit. De twee Fortran-bestanden zijn uitsluitend observatiekopieën.

De losse Python-beoordelaar berekent zelf de waterhoeveelheden uit theta, matrixfractie, laagdikte en macrovoorraden. Hij reconstrueert de interne Darcy-fluxen uit drukhoogten en celafstanden, met de oorspronkelijke semigeïmpliciete geleidbaarheden (`SWKIMPL=0`). Hij gebruikt hiervoor **niet** de door `FLUXES` uit waterbehoud afgeleide verticale fluxvector: dat zou het matrixbewijs circulair maken.

Voor deze stap gelden `SWMBF=1`, vijf domeinen, 112 matrixcompartimenten, onveranderde matrixfracties en nul immobilisatieterm. De werkelijke sink-, source- en wortelvectoren worden gecontroleerd. Negatieve-voorraadbegrenzing is in geen van de vijf domeinen actief. De referentie-uitwisseling wordt per compartiment onafhankelijk uit de vijf domeinen opgeteld.

De oorspronkelijke lokale/totale/pondcriteria blijven ongewijzigd. Domein- en aggregatiesommen gebruiken alleen een afrondingsenvelop van `64*machine-epsilon*voorraadschaal`; dit is geen nieuwe fysische tolerantie. De scripts starten bij gegevensbeoordeling geen model of compiler.

## Resultaten

Alle vier primitieve uitvoervectorbestanden zijn **bytegelijk O0/O2**. De definitieve O2-route duurde `0.817 s`; O0 `1.287 s`. Geen van beide bereikt de twintigsecondenlimiet.

| Grootheid | Gemeten hoeveelheid of sluitfout |
| --- | --- |
| Matrixvoorraadverandering | `+4.529194942943462e-6 cm` |
| Totale macrovoorraadverandering | `-2.241665299046111e-5 cm` |
| Oppervlaktevoorraadverandering | `0 cm` |
| Gecombineerde voorraadverandering | `-1.788745804751765e-5 cm` |
| Onafhankelijke externe netto waterhoeveelheid | `-1.788745775046672e-5 cm` |
| Matrixbalansfout | `-2.972201427168955e-13 cm` |
| Totale macrobalansfout | `+1.692168540706751e-16 cm` |
| Grootste afzonderlijke domeinbalansfout | `1.781e-16 cm` |
| Oppervlaktebalansfout | `0 cm` |
| Gecombineerde balansfout | `-2.970509275568908e-13 cm` |
| Onafhankelijk opnieuw opgetelde matrix/macro-uitwisseling | maximum verschil `1.735e-18 cm/d` |
| Grootste lokale residu | `1.712015348931395e-9 cm/d`, grens `1e-6` |
| Som residu | `-2.101663816426414e-9 cm/d`, absolute grens `1e-5` |
| Verschil zelfstandig gereconstrueerd en modelresidu | maximum `6.939e-18 cm/d` |

De matrixbalansfout is precies de verwachte kleine integraal van het geaccepteerde totale residu, binnen afronding. De gecombineerde fout wordt door die matrixterm verklaard; zij wijst niet op verdwenen macro-uitwisselingswater. De som van de geaccepteerde compartimentvoorraden reproduceert elke domeinvoorraad tot afronding. De volledige domeinwaarden staan in `RESULT.json`.

De door `FLUXES` uit behoud gereconstrueerde bovenflux verschilt `2.101663522033337e-9 cm/d` van de werkelijk opgelegde solver-bovenflux. Dat is de kleine totale residuterm. De onafhankelijke controle gebruikt de opgelegde flux en rapporteert de resulterende voorraadfout, in plaats van die fout stilzwijgend weg te definiëren.

## Aanvullende observatie: reductievlag na acceptatie

De oorspronkelijke `headcalc` verlaagt `IDecMpRat` na snelle acceptatie alweer met één. De operator is hier gecertificeerd op niveau één, maar de routine keert terug met niveau nul. De gebruikte uitwisselingsflux blijft die van het gereduceerde probleem. De drie metingen zijn consistent:

- aan het begin van de geselecteerde poging: `IDecMpRat=1`;
- bij het gecertificeerde residu: `IDecMpRat=1`, exact dezelfde F/q als STATE02;
- na terugkeer en geaccepteerde voorraadupdate: `IDecMpRat=0`.

Een controle die alleen de vlag ná terugkeer bekijkt, mag dit dus niet als een ongereduceerde acceptatie classificeren. Dit is een observatie over het bestaande reductiebeleid, geen aangetoonde nieuwe solverfout. De bronnen, wet en policy zijn niet gewijzigd.

## Bewaarde setupfouten en kosten

Er waren drie setup-routes vóór de twee definitieve routes. De eerste selector onderschepte een verworpen minimumdt-poging waarin `headcalc` net reductieniveau één had ingesteld; de defensieve controle stopte met foutcode één na `1.283 s`. Die uitvoer en de exacte oude bron/buildidentiteit zijn bewaard in `setup-selection/` en de Git-checkpoints.

De tweede selector controleerde de vlag na terugkeer en miste daardoor de stopplaats, omdat de oorspronkelijke code de vlag daar al naar nul had verlaagd. Deze twee O0/O2-routes voltooiden onbedoeld het bestaande tweedaagse venster in `1.375/1.017 s`. Dit waren selectie-/instrumentatiefouten; zij zijn niet als extra campagne of nieuw fysisch kwalificatiebewijs gebruikt. De records en einduitvoer staan in `setup-postaccept/`. Dit wijkt af van het voornemen uitsluitend prefixes te draaien; er is geen nieuwe 481-daagse run uitgevoerd en geen tijdslimiet verhoogd.

De definitieve selectie legt het exacte t/dt/niveau bij binnenkomst vast met één private diagnostische vlag en volgt diezelfde poging tot na acceptatie. Zij verandert geen modeltoestand of beleid. Na deze reparatie zijn alleen de twee geselecteerde O0/O2-routes uitgevoerd.

Alleen de twee observatieobjecten zijn opnieuw gecompileerd en gekoppeld met GNU Fortran 16.2.0, native MSYS2 UCRT64 Windows. De overige objecten/TTUTIL komen uit de op SHA-256 geverifieerde STATE02-bewijscapsule. `O0_IDENTITY.json` en `O2_IDENTITY.json` binden elke definitieve executable aan de bron- en objecthashes. Geen brede rebuild of algemene testcampagne was nodig.

## Advies en resterende beslissing

**Voor een fysische B1-referentie adviseer ik ongereduceerde gekoppelde convergentie.** Het hoofddoel is een betrouwbare fysische vergelijkingsbasis. STATE02 bewijst dat reductie de daadwerkelijk geaccepteerde uitwisseling verandert en dat alle elf betreffende drukhoogtetoestanden het ongereduceerde criterium missen. Deze inventaris bewijst nu dat zo'n andere oplossing wél conservatief kan zijn. Behoud en ongereduceerde convergentie zijn dus afzonderlijke voorwaarden.

V1 met de oorspronkelijke reductie blijft waardevol als herkenbare numerieke onderzoeksvariant en voor vergelijking met historisch gedrag. Gebruik daarvoor expliciete aanduiding van het gebruikte reductieniveau. Zij mag op basis van deze resultaten niet als ongereduceerde fysische referentie of als officiële B1.12-opvolger gelden.

De eerstvolgende concrete stap na vastlegging van dat referentiecontract is één afzonderlijk geregistreerde heroplossings-/afwijzingsproef op dezelfde eerste reductiecontext. Daarbij moet het oorspronkelijke ongereduceerde residu aan het bestaande criterium voldoen; een losse fluxverversing is onvoldoende. De oorspronkelijke reductieregel wordt niet stilzwijgend gewijzigd. Die alternatieve solverproef is nu niet gestart.

De oorspronkelijke droge/eventeindafwijzing en korte eigen herstart blijven open. Daarvoor is nog geen onderscheidende volledige begincontext beschikbaar; deze inventaris sluit dat geheugendossier niet alsnog. Geen B0-, B1.12-, canonical- of releasewijziging en geen promotie-PR.

Reproduceer alleen de gegevensbeoordeling met `python research/swap431-macro-b1-inventory03/assess_inventory03.py`.
