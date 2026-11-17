# Afgebakend fysisch contract: node 47, GWL rond -60 cm

**Besluit:** de hele-celuitsluiting is een bewuste implementatiekeuze. Voor de onderzochte oorspronkelijke veldconfiguratie veroorzaakt zij een aantoonbare afwijking van het gedocumenteerde Darcy-contract: een nog onverzadigde matrix met watercontact, positieve geleidbaarheid en positieve drukgradiënt ontvangt nul instroom, zonder overdracht naar de verzadigde uitwisseling. De claim betreft dit concrete ontbrekende contact en deze huidige kandidaat; de oorspronkelijke auteursintentie achter alle historische versies is niet vastgesteld.

## Gezag en concrete tegenspraak

Kroes et al. (2017), SWAP version 4, WER2780, gedrukte pp.100 en106, beschrijven laterale infiltratie over het contact tussen macroporiewater en onverzadigde matrix. Darcy en sorptie worden berekend en de grootste relevante rate wordt gekozen; Eq.6.32 en6.57 koppelen Darcy aan de lokale drukgradiënt en geleidbaarheid. De verzadigde uitwisseling heeft een afzonderlijk contract (Eq.6.35/6.58). [Oorspronkelijk WUR-rapport](https://edepot.wur.nl/416321#page=108).

De handleiding onderbouwt geen volledige uitschakeling van dit nog aanwezige onverzadigde contact zodra de GWL een celondergrens passeert. De bron documenteert zo'n uitsluiting wel: `ABSORPTION` eindigt op `ICpTpSatZon-1`. Dat broncommentaar is bewijs van de gekozen discretisatie, maar geen fysische afleiding van een nulpunt van de Darcy-term.

De gecontroleerde zijde GWL=-59,99999999 cm heeft:

- H47=-0,8458571797678278 cm en thetaS-theta=6,159412092032746e-7;
- een geometrisch onverzadigde celfractie 0,9999999949999996;
- positieve druk in domein 4 van 9,123281312644309 cm; macroporiewater bedekt de hele celwand;
- positieve bestaande geleidbaarheid en contactcoëfficiënt, met oorspronkelijke SorpFac=0,9998312355865097;
- ongeclipte instroom-/uitstroomfactoren één en fluxfactor één;
- een positieve Darcy-kandidaat 0,05653615225394495 cm/dag;
- werkelijk nul ongesatureerde én nul verzadigde instroom in node47.

Aan de andere zijde op -60,00000001 cm geeft dezelfde originele provider 0,056536152445578504 cm/dag in domein4, exact gelijk aan de onafhankelijk gereconstrueerde Darcy-term. De parameter-, druk- en contactvariatie wordt bij kleinere offset kleiner; de gemeten sprong blijft eindig. Dit is geen verdwijnend watercontact, volle matrix, voorraadtekort, reductiefactor of verouderde cache.

## Minimale afbakening voor eventueel contractherstel

Een minimale herstelkandidaat moet het daadwerkelijk onverzadigde, met water in contact staande deel van de GWL-cel toegang geven tot de bestaande laterale wet en aansluiten op de aangrenzende volledig onverzadigde cel. De opsplitsing met de verzadigde uitwisseling moet sluitend blijven. De bestaande sorptie/Darcy-selectie, drukgradiënt, domeinvoorraden, reductieregels en proceshistorie blijven randvoorwaarden.

De precieze gedeeltelijke contactweging, sorptiehistorie, afgeleiden, dubbel tellen met SATFLOW en gedrag op de exacte geometrische grens vragen eigen implementatie- en kwalificatiebewijs. De geometrische fractie in deze ronde is een onafhankelijke controle van de aanwezigheid van contact; zij is geen toegelaten nieuwe fluxformule. De drie tweezijdige proeven raken de exacte grens niet.

Deze beslissing rechtvaardigt gericht ontwerp van zo'n minimale herstelkandidaat binnen dezelfde context. Zij voert geen herstel uit en bewijst geen verbeterde convergentie, volledige periodebalans, nieuwe herstart of algemene correctie voor alle GWL-/perched-zones. De bestaande Jacobiaanvoorwaarden blijven behouden; zij vertegenwoordigen een ander gekwalificeerd geometrisch regime.
