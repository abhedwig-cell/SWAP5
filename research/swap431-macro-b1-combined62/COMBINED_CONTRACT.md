# COMBINED62 — gecombineerde domein3-aanvulling zonder dubbeltelling

Status: gecombineerd conditioneel contract gekwalificeerd op de twee oorspronkelijke D2-providerpunten53/54, met alle acht actieve kolommen en buitencontrole49, O0/O2. Geen correctie in de lineaire solve geïnstalleerd; geen convergentie- of conditioneringstoets van een gecorrigeerde solve. FACTOR60 en POTENTIAL61 blijven de owning afgeleidecontracten en hun grenzen gelden onverkort.

## Ownership en teken

De matrixresiduoperator bevat -q_i. Met P_i de potentiële D3-uitflux per dag, f de actuele uitfactor en K_ij=dP_i/dH_j is de volledige domein3-afgeleide binnen deze context

`J3_full(i,j) = -f*K_ij - P_i*v_j`, v_j=df/dH_j.

Deze J3_full mag NIET volledig op de bestaande Jacobiaan worden opgeteld. De bron voegt verzadigde lokale D3-afgeleiden al toe aan dFdhMp en trekt het totaal in jacobian_F van de diagonaal af. Noem deze actuele reeds aanwezige residubijdrage J3_local. De juiste aanvulling is

`DeltaJ3 = J3_full - J3_local`.

Dan geldt `J_existing+DeltaJ3 = (J_existing-J3_local)+J3_full`; matrixfysica en domeinen1/2/4/5 worden niet opnieuw toegevoegd of afgetrokken. Voor deze gekwalificeerde context zijn D3-matrix-/interne instromen0 en er is geen reeds actieve JAC24/37-niet-lokale correctie. Een toekomstige andere overlappende correctie vereist expliciete ownership of afwijzing. Niet alle dFdhMp aftrekken: dat zou de andere domeinen beschadigen.

## Werkelijk aanwezige D3-bijdrage

COMBINED62 observeert dFdhMp vóór/na de echte D3-ABSORPTION(2) en SATFLOW(4), op de twee oorspronkelijke actuele Jacobiaanevaluaties. Er is geen gekopieerde vervangende derivativeprovider. De directe increments zijn per cel vastgelegd; de totale dFdhMp blijft exact gelijk aan de bestaande headcalc-diagnostiek.

De D3-onverzadigde increment is overal0, omdat het actuele QOut in cel50 onder de originele1e-7-grens van de lokale derivativetak ligt. De verzadigde D3-increment is alleen51..57 niet nul. In residuteken geldt daar

`J3_local(i,i) = f*FrReduQ*CDarcy(3,i) = -f*K(i,i)`, i=51..57.

De gemeten increments sluiten hierop tot6,40e-18. De zeven verzadigde diagonalen moeten dus eenmaal behouden blijven; ze horen niet opnieuw in de netto aanvulling. Op cel50 is J3_local0 binnen de geselecteerde gate.

## Twee buitenproducten

Schrijf de POTENTIAL61-gradiënt als K=D+e50*a^T: D bevat de zeven verzadigde diagonalen, a bevat de contact-/vochtgradiënt in rij50. Dan cancelen -f*D en de werkelijk aanwezige J3_local binnen afronding.

De netto aanvulling is

`DeltaJ3 = u*v^T + e50*w^T`

met

`u_i = -P_i`

`v_j = -(L_j+f*O_j)/O`

`w_j = -f*a_j - J3_local(50,50)*delta_(j,50)`.

Hier zijn O de totale potentiële hoeveelheid [cm] en O_j de afgeleide van die hoeveelheid; L_j is de FACTOR60-minimumvoorraadgradiënt. P en K zijn rates [cm/dag] en hun headgradiënten. De aanvulling heeft eenheid1/dag. Alleen deze eenhedencombinatie voorkomt een verborgen extra of ontbrekende dt-factor.

Op het W-punt53 is L_j0 en het contact gesloten, dus w0: rang hoogstens1. Op het V-punt54 bevat L de volledige getoetste GWL-/geometrieketen en a de cel50-contact- en vochttermen: rang hoogstens2. w is hier uitsluitend op kolommen50/51 niet nul. De factorbijdrage bevat de volledige P-vector, inclusief het kleine onverzadigde P50. Ook daardoor kan de totale correctierij50 op kolommen52..57 kleine niet-nulwaarden hebben; deze mogen niet met de schaarsere w-rij worden verward of naar0 afgerond.

De algemene veilige definitie blijft J3_full-J3_already_present. De bovenstaande compacte vorm is alleen geldig als de gemeten/verifieerbare lokale ownership-identiteit en alle factor-/potentievoorwaarden gelden. De geobserveerde aftrekafronding is maximaal6,40e-18; geen fysische drempel wordt hiervoor gewijzigd.

## Waterbalansafgeleide als onafhankelijke controle

Omdat de totale D3-uitstroom qtot=(W+I-L)/dt en W/I/dt vast zijn, geldt

`sum_i J3_full(i,j)=L_j/dt`.

Op W is de kolomsom0; op V gelijk aan de echte volumeonder-GWL-gradiënt per dt. De netto aanvulling heeft daarom kolomsom L_j/dt minus de huidige lokale kolomsom. Dit voorkomt dat behoud van een verkeerde lokale diagonaal ongemerkt als verbetering wordt geteld. De toets sluit tot5,69e-14. Dit is de afgeleide van het D3-operatorcontract, geen nieuwe geaccepteerde tijdstapbalans.

## Guards, actuele payload en transactie

Toelating erft de volledige FACTOR60/POTENTIAL61-envelop: dezelfde actieve D3-uitfactor, constante positieve boveninstroom, vaste W/dt, FrIn1, oorspronkelijke excessdrempels, cel50/ondersteuning, materiaal-/geometrie-/macrohoogte-/historievoorwaarden, SwAbs1/startklok/sorptiviteitswinnaar/ongecapte potentie, juiste minimum- en contacttak en geen ties of ondersteuningsovergangen. Geen JAC24/37-guard versoepelen.

Alle combinatietermen en aanwezige lokale bijdragen moeten horen bij dezelfde actuele heads/t/dt/poging/iteratie/sequence/taak. Een geldig numeriek payload-/restorecontract is vereist. sample46 en de nieuwe owner-log zijn hier diagnostiek; zij zijn geen reeds toegelaten numerieke cache en mogen niet zonder actuele stempel-/herstelgarantie worden geconsumeerd. Een latere implementation moet nul-/ongeldige/stale payloads afwijzen, scratch/inactiviteit expliciet behandelen en mislukte proeven volledig herstellen. Geen nieuwe native fysieke toestand wordt door deze afbakening geïntroduceerd.

Elke echte lijnproef blijft de oorspronkelijke operator en actuele minimum-/contacttak evalueren. Buitencontractgevallen, ties, gewijzigde instroom/geometry/materials/event/cap, f0/f1/O0 of overlappende niet-lokale correcties vergen afwijzing of een eigen geldig contract. Geen nieuwe toleranties om toelating te fabriceren. De latere lineaire solve kan twee buitenproducten gebruiken, maar invertibiliteit, numerieke conditionering, solverfallback en convergentie zijn hier niet getoetst of gewijzigd.

## Kwalificatie

Twee oorspronkelijke D2-punten, alle actieve heads50..57 en buitencontrole49 met geërfde48 echte providerperturbaties/route. Gemeten lokale ownership, volledige gecombineerde matrix, twee-buitenproductsplit, behoud van verzadigde diagonalen, negatieve dubbeltellingscontrole, massderivative en provider-FD over alle112 uitvoerrijen zijn getoetst. De ruwe gecommitteerde floatfactor heeft aftrekafronding; FD-vergelijkingen gebruiken expliciete propagatie van die afronding, de reeds gekwalificeerde geometrie-/potentieketen en eindige stapgemiddelden. Dit verandert geen fysisch solvercriterium.

Niet gekwalificeerd: implementatie in de solve, nieuwe richting/rollback/retry/hostcommit, alle112 onafhankelijke headperturbaties of een algemeen toestands-/volledige-operator-/herstartcontract. De volledige domein3-afgeleide is conditioneel; overige domeinen en canonieke productie blijven onaangeraakt.
