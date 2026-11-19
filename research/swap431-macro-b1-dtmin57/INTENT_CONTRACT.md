# DTMIN57 — afgebakend numeriek contract

Status: consistent correctiecontract voorgesteld en rekenkundig getoetst; niet geïmplementeerd in de solver en niet canoniek toegelaten. Toepassing uitsluitend op dezelfde oorspronkelijke D2-vervolgcontext binnen B1-onderzoek.

## Wat de bronnen wel en niet vaststellen

De oorspronkelijke headcalc (STATE02-identiteit SHA256 db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5) toont de bestaande dtmin-uitzondering. De actuele numerieke documentatie beschrijft factor-of-three backtracking en noemt daarnaast historische minimumstapbegrenzing, maar specificeert niet hoe beide moeten worden gecombineerd. Die documentatie beschrijft de bevroren no-macro owner; ze bewijst niet de historische auteursbedoeling van deze macro-uitzondering. Die specifieke bedoeling blijft UNKNOWN.

De bron en O0/O2-waarnemingen bewijzen wel dat de bestaande terugzoekfactor in de dtmin-uitzondering geen effect heeft. Vanuit het expliciete doel om na onvoldoende voortgang een kleinere proef te nemen, is dit numeriek inconsistent. Behoud van de stapgrens én daadwerkelijke factor-of-three-verkleining leidt tot het onderstaande minimale contract. Het is een onderbouwde herstelkeuze, geen teruggevonden auteursverklaring of bewezen convergentie-oplossing.

## Beginstaat, activatie en richting

Neem per Newtoniteratie vaste pre-update heads H en de eenmaal berekende richting D, met J D=F en teken H-D. Proeven beginnen steeds opnieuw bij H; ze accumuleren niet op de vorige proef. De relatieve limiter is uitsluitend actief in de bestaande tak `fldtmin .AND. numbit>MaxIt`. De eerste MaxIt-iteraties blijven onder de normale update. `MaxIt1=2*MaxIt` bij fldtmin of fldecmprat is op zichzelf geen activatie van de limiter; het tweede geval zonder fldtmin blijft buiten deze tak. Geen uitbreiding naar andere stappen.

Definieer s_i=1 cm als |H_i|<1 cm, anders |H_i|. Bij exact 1 cm geven beide dezelfde schaal. Met M=max_i(|D_i|/s_i) is de bestaande begrenzing alpha0=min(1,1/M). Voor de wiskundige nulrichting M0 geldt de continue waarde alpha0=1. De solverberekening van die degeneratie wordt hier niet gewijzigd of apart als runtimegeval gekwalificeerd.

De grens is gemengd: maximaal1 cm absolute verandering nabij nul; maximaal100% relatieve verandering daarbuiten. Ze begrenst de Newtonstap, niet de residunorm of waterbalansfout. Dezelfde positieve schaal geldt voor alle componenten, zodat richting en teken behouden blijven.

## Samenstelling met backtracking

Binnen de speciale tak wordt eerst de begrensde richting P=alpha0 D bepaald. Proef k, nulgebaseerd, neemt

`H_trial(k)=H-factor(k)*P`, met `factor(k)=3^(-k)`.

Equivalent is de effectieve schaal alpha(k)=alpha0*factor(k). alpha0 blijft constant binnen de terugzoeklus. De eerste proef blijft de bestaande begrensde proef. Bij niet-nul D wordt iedere volgende proef daadwerkelijk een factor3 kleiner. De gemengde stapnorm is hoogstens factor(k), dus geen enkele proef overschrijdt de oorspronkelijke grens. Bij alpha0=1 valt de formule samen met gewone backtracking. Buiten de speciale tak verandert niets. Een eventuele minimale implementatie moet de bestaande begrensde richting met factor vermenigvuldigen en de eerste proef behouden.

Alleen `min(alpha0,factor)` gebruiken is onvoldoende: wanneer alpha0 kleiner is dan meerdere opeenvolgende factoren blijven die proeven identiek. De limiter na iedere geschaalde richting opnieuw toepassen geeft hetzelfde plateau. De productvorm voorkomt dit zonder een nieuwe parameter, stapgrens of zoekrichting.

## Voortgang, uitputting en transactie blijven apart

De bestaande voortgangstest blijft `sump<sumold OR Fmax<CritDevBalCp`, met sump=.5 dot(F,F). Vier werkelijke lijnproeven blijven vier; een uitgelopen teller5/factor1/81 is geen vijfde proef. Iteratielimieten, hoofd- en totaalresiducriteria, head-/pondcriteria, oorspronkelijke laatste-proefafhandeling bij uitputting, dt-verkleining en schaalverzoek blijven behouden. Het contract belooft daardoor geen monotoon dalende iteratie-einden na uitputting. Het introduceert geen nieuwe acceptatie of afwijzing.

Een complete geaccepteerde tijdstap blijft aan alle bestaande gekoppelde criteria en hostcommitvoorwaarden onderworpen. Dezelfde rollback/inventaris-/retrykwalificatie blijft nodig voor een toekomstige implementatie. Fluxreductie, tolerantieverruiming of overslaan van een foutcriterium is geen onderdeel van dit herstelcontract.

## Toetsing en expliciete grens

O0/O2 observerruns leveren alle227 werkelijke proeven met volledige112-componenten H,D,H_trial. De oorspronkelijke update is exact gereconstrueerd (maximale absolute afwijking0). De60 proeven in de extra30 dtmin-iteraties hebben M in [6.61108586281943e-5,0.022774356733347288], dus alpha0 overal1. Hier werkt de limiter nergens: de ontbrekende backtrackingfactor laat telkens de volledige Newtonrichting staan. Tien uitputtingen geven vier exact identieke volledige richtingen en proefheads;30 evaluaties zijn herhalingen.

Zes modelvrije algebraïsche gevallen toetsen de productvorm: beide zijden van1 cm, tekens, limiter actief/inactief/exactgrens, nulrichting en bijna nul. Dit zijn formulechecks, geen extra fysieke contexten of modelroutes. De alternatieve heads worden niet in de echte operator geëvalueerd; er is geen uitspraak over hun residu, nieuwe iteratierichting, totale rekentijd of uiteindelijke convergentie. Dat vergt een volgende minimale implementatie en gerichte O0/O2-kwalificatie binnen dezelfde grenzen.
