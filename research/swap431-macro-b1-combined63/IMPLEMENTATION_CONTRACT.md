# COMBINED63 — minimale COMBINED62-implementatie

Status: geïmplementeerd en op dezelfde oorspronkelijke D2-vervolgstap getoetst, O0/O2. De grotere poging wordt werkelijk geweigerd; de ongereduceerde dtmin-retry convergeert en krijgt één hostcommit met onafhankelijke waterinventaris. Geen canonieke/algemene toelating.

## Huidige providerpayload

De echte MacroRate berekent canonical37 en de D3-potenties. Vóór de lokale derivativetaken worden de actuele verzadigde/onverzadigde potenties opgeslagen in eigen sat63/uns63-scratch, met seq63=macro_seq. De getter geeft alleen een geldige payload bij ready/task2, gelijk t/dt/poging/iteratie/sequence en volledige headgelijkheid. Hij reconstrueert geen historische sample46 en leest geen ownerlog.

Dit opslagmoment is noodzakelijk: ABSORPTION(2) initialiseert de live onverzadigde potentiewerkarrays opnieuw. Een live-arraygetter na die taak levert dus geen geldige V-potentie. De eerste guarded implementatie liep hierop vast; de initiële routes/bronnen/binaries zijn behouden. Dit is opgelost door de payload vóór de derivativetaak te bewaren, zonder een guard of fysische operator te veranderen.

seq63/sat63/uns63 zijn opgenomen in de actuele scratch- en cache-serializers. Dit zijn onderzoekssnapshotinterfaces; oudere debug-/calibratiesnapshots zijn niet daarmee compatibel verklaard. Het ongewijzigde runner-calibration_base.bin is in deze routes niet ingelezen. De native fysieke V6-layout en haar fysieke velden zijn niet gewijzigd. Er zijn in deze unit geen nieuwe snapshot-roundtrip- of fresh-follow-restartproeven uitgevoerd; daadwerkelijke current-stamps en de grotere-pogingrollback worden wel gecontroleerd.

## Afgebakende toelating

De corrector is uitsluitend actief op de opgeslagen oorspronkelijke vervolg-tijd35797.290431125148 met n112/5domeinen, kandidaatpad, swmbf1/IcTop1/IDec0/FrRedu1. Hij valideert de COMBINED62-cel50/ondersteuning, positieve constante verticale D3-instroom zonder andere instromen/exces, FrIn1, strikte gedeeltelijke uitfactor en originele excessdrempels, L=min(V,W), geen tie/volumeclip en overeenkomstige W-gesloten/V-gedeeltelijk-contacttak.

ICpTpWaSrDm3=50 en ICpBtDm3=57, H50<0 en H51..57>0, verzadigde theta51..57 en near-saturated theta50 maken de afgebakende geometriegradiënt geldig. De cel50-vochtdeficit moet boven1e-8 en onder de bestaande geometrie-updategrens liggen; SwAbs1/SwDarcy1/startklok0, positieve sorptiviteit en inactieve cap blijven voorwaarden. De potentiële sat-support is exact51..57; uns-support alleen50; huidige D3-matrix-/interne instromen0.

De aanwezige lokale onverzadigde D3-afgeleide moet binnen deze implementatie nog afwezig zijn volgens haar bestaande QOut>1e-7-gate. Zo blijven de zeven satdiagonalen eenmaal behouden en hoeft geen niet-gekwalificeerde actieve U-lokale derivative te worden afgetrokken. De zes grotere-pogingproviders met hogere U-flux vallen daarom correct terug op het bestaande pad. JAC24/37 zijn door deze disjuncte voorwaarden niet gelijktijdig actief; hun guards zijn niet gewijzigd. Een ongeldige payload of buitencontractgeval activeert de nieuwe aanvulling niet.

## Termen en solve

De termen volgen COMBINED62 zonder dubbeltelling:

`DeltaJ=(-P)*df^T + e50*w^T`

`df=-(dL+f*dO)/O` en `w50/51=-f*dU50/dH50/51/dt`.

De zeven verzadigde diagonalen blijven in de bestaande tridiagonale matrix staan. De actuele lokale U-bijdrage is door de hierboven genoemde guard0. De P-vector bevat zowel verzadigde als de kleine onverzadigde potentie. Potentiegradient, contact en officiële moiscap-vochtketen zijn ongewijzigd uit het gekwalificeerde contract afgeleid; geen fysische threshold of klok wordt aangepast.

De bestaande tridiag- en rang2-Woodbury-werkwijze is gebruikt met dezelfde1e-12 determinantgrens als JAC37. Actieve basis/update-/singulariteitsfouten stoppen fail-closed zoals dat bestaande updatepad; geen stille ongereduceerde verkeerde solve. Alle actuele A/r/U/V/x zijn gelogd en onafhankelijk nagerekend. De corrector wijzigt uitsluitend de Newtonrichting. De gewone vier lijnproeven, MAXIT30/60, DTMIN58-stapupdate, criteria, fresh-vectorcontrole, dt-/reductie- en hostcommit-/budgetregels blijven behouden.

## Toetsuitkomst en grenzen

O0/O2 eindroutes normaal1,418/1,229 s, onder hard20s met originele interne16s/512commit/4retrygrenzen. Grotere poging30iter geweigerd, fysieke toestand en ledger vóór de kleinere retry exact hersteld behalve gewone dt/fldtmin. De dtmin-retry heeft3Jacobiaangebruiken: één W-rang1 en twee V-rang2. Fresh controle slaagt met Fmax3,044456621352498e-8, som2,0918085756152195e-7, FrRedu1/IDec0. Eén volledige hostcommit.

O0/O2-fysieke uitvoer en follow.end zijn byte-identiek. Onafhankelijke inventarisfout2,0919129474248157e-12 cm versus bestaande1e-10 cm-grens. Lineaire systeemafwijking maximaal9,43e-18; D3-massderivativecheck maximaal1,14e-13.

Niet gekwalificeerd: directe kleinere retry vanuit een onafhankelijk vers proces, geforceerde afwijzing met actieve V-aanvulling, nieuwe eigen follow.end-herstart/continue-vergelijking, gehele periode/BAL, algemene ondersteuning of B1-promotie. De grotere poging convergeert nog niet. Native fysieke velden zijn behouden, maar volledige native-herstartclaims vergen een eigen test. B1 blijft kandidaat met expliciete uitsluitingen.
