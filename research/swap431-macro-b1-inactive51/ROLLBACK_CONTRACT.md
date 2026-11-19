# INACTIVE51 - afgebakend rollbackcontract

Voorgesteld contract voor dezelfde oorspronkelijke D2-transactie, te toetsen met waarnemingen op de ongewijzigde implementatie. Geen rollbackreparatie in deze unit.

## Geaccepteerde historie

Een afgewezen proef mag ThtSrpRefDmCp en SorpDmCp niet wijzigen in de teruggegeven geaccepteerde toestand, ook als TimAbsCumDmCp nul is. Rollback herstelt exact de waarden van de oorspronkelijke saved state; geen generiek nulzetten of vervanging door theta_s. De oorspronkelijke waarden kunnen betekenis hebben voor native representatie en inspectie, ook waar de fysieke rate ze bij het volgende nieuwe event opnieuw initialiseert.

TimAbsCumDmCp behoort tot dezelfde eventhistorie en moet ongewijzigd zijn tot een echte hostcommit. In de huidige code schrijft alleen de owner deze klok; tijdens de afgewezen D2-pogingen blijft hij al exact gelijk. Dit contract wijzigt geen klok, eventstart/-einde of sorptiewet. Reeds actieve histories krijgen dezelfde exacte herstelgarantie als inactieve histories.

## Minimale benodigde aanvulling

De bestaande MACROSTATEVAR(1)/(2)-eigenaar bewaart/herstelt watergeometrie maar geen referentie of oorspronkelijke sorptiviteit. Voor dit afgebakende contract ontbreken twee geaccepteerde-origin snapshots: ThtSrpRefDmCp(1:NumDm,1:NumNod) en SorpDmCp(1:NumDm,1:NumNod). Bewaar beide bij de oorspronkelijke saved-stategrens en herstel ze bij iedere afwijzing voordat een nieuwe retry-snapshot wordt gemaakt. Bewaar alle betrokken domeinen/cellen, zonder hardcodering op de twee gevonden velden of een tau0-test. Dat voorkomt dat een algemene fysieke eventhistorie afhankelijk wordt van de toevallig bezochte proeftak.

Een aanvullende klokbuffer is voor deze D2-minimale correctie niet nodig zolang providers TimAbsCumDmCp niet schrijven; controleer die onveranderlijkheid expliciet. Geen nieuw native formaat: beide velden bestaan al in de native serializer. De nieuwe originsnapshots zijn uitsluitend tijdelijk transactiescratch. Een geldige saved-stategrens moet na de native restore en vóór een proef bestaan; rollback zonder zo'n origin is ongeldig. Na herstel mag een retry opnieuw een snapshot nemen, en een volgende echte acceptatie bepaalt de nieuwe origin. Geen dubbele ownercommit of wijziging van het CONTACT47-incrementcontract.

## Herberekenbaar werk

FlEndSrpEvt, FlSorp, providerfluxen/-derivatieven en CONTACT47 delta/mask/stamp zijn werkgegevens. De CONTACT47-cache wordt bij rollback ongeldig en nul; de volgende rate berekent werkgegevens opnieuw vóór gebruik/commit. Zij hoeven niet alle op de oorspronkelijke bytes te worden teruggezet om dit sorptiehistoriecontract te sluiten, mits actualiteit en ongeldigheid aantoonbaar zijn. AwlCorFac is bestaande bewaarde geometrie/historie; deze blijft in D2 al exact gelijk en krijgt hier geen nieuwe formule of snapshot. Eventuele andere schrijfregimes vallen buiten deze toets.

VlMpDyCp/SubsidCp en overige flux-/boundaryhelpers blijven expliciet buiten deze afbakening. Exact herstel van twee sorptievelden verleent dus geen volledige native snapshot-/herstarttoelating.

## Toets en grens

Exact dezelfde oorspronkelijke D2, geen selectie of forcingwijziging. Twee nieuwe observer-only TRIAL-replays O0/O2; hard20/internal16 inclusief oorspronkelijke prefix; bestaande kandidaat512commit-/4retrygrenzen. Vergelijk alle oude uitvoer tegen SELECT50. Controleer gewijzigde referentie/sorptiviteit per rollback uitsluitend bij tau0, behoud alle klok-/actieve histories, log pre/post nieuwe-eventinitialisatie en bewijs overschrijving vóór gebruik. Hergebruik de bestaande DIRECT-D2-equivalentie uitsluitend bij ongewijzigde bronafhankelijkheid en exacte TRIAL-uitvoer.

De huidige implementatie wordt beoordeeld tegen dit nieuwe contract en mag FAIL/OPEN zijn. Een definitie is geen geïmplementeerde restauratie of nieuwe herstart-PASS. Geen synthetische vergiftiging, extra provider, gevoeligheidscontext of brede campagne. B1 blijft kandidaat met expliciete uitsluitingen, beschermde workstreams onaangeraakt.
