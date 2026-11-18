# FEEDBACK48 - minimale CONTACT47-reparatie en terugkoppeling

De minimale implementatie slaagt voor dezelfde90 events met O0/O2. De theoretische referentie krijgt de positieve increment uit de laatst geaccepteerde RATE in plaats van de nulgewogen END-increment. De volgende rate gebruikt deze bijgewerkte referentie daadwerkelijk voor S_active; de terugkoppeling is dus uitgevoerd, niet alleen algebraisch voorspeld.

## Wijziging

Alleen de theoretische referentiebijwerking voor de door REPAIR43 meegenomen main-GWL-contactcel is gewijzigd. ABSORPTION berekent dezelfde CONTACT47-increment met oorspronkelijke SorpDmCp, bestaande tau en dt, Awl/Pp/DiPo en eenmaal wet_RATE/contact_RATE. FrOut, FrReduQ, actuele SorpAct en FrArMtrx worden niet in die theoretische teller opgenomen. De bestaande werkelijke fluxwetten, caps, eventflags, derivatieven en voorraadbegrenzing blijven intact.

Scratch in ABSORPTION bevat per domein/node de increment en een masker. Iedere MACRORATE-aanroep en iedere nieuwe poging maakt deze ongeldig; de laatste TASK1 zonder probe verzegelt tijd/dt/poging/iteratie/generatie/nvec en alle heads. MACROSTATE controleert en consumeert die eenmaal voordat de eindgeometrie verandert. MacroStateVar(2) invalideert bij rollback. Bestaande eventeind-/droogreset blijft prioriteit houden. Er is geen nieuw persistent/native veld. IMPLEMENTATION.patch bevat de volledige bronwijziging tegen CONTACT47; geen activering op specifieke node, domein, poging of tijd.

De CONTACT47-bronfysica is verder ongewijzigd. De tijdstapkeuze en iteraties kunnen door de bedoelde referentieterugkoppeling wel anders uitvallen; daarvoor zijn geen besturingsregels gewijzigd.

## Dezelfde90 en terugkoppeling

Start is dezelfde oorspronkelijke native checkpoint35797, SHA256 21bd728c9983d6a0d4e82d6b2fd12729dc02284277a5dab5d296d8edc1dcbf16. Initial/begin context, waterinventaris en ledger zijn exact gelijk aan CONTACT47. De reparatie is vanaf de eerste eigen head actief; geen ouderprefix of bevroren toestand wordt ingevoegd.

De selectie blijft exact90: D3/node50/pogingen36..125, op dezelfde tijden en dt als CONTACT47, met nul ENDcontact en positieve sorptie. Oorspronkelijke sorptiviteit en contactklok zijn exact gelijk aan de ouder. Elke increment is positief en voldoet aan het contract. De som berekende incrementen is 1.782871767187086e-8; de som opgeslagen verschillen is 1.7828717502332836e-8 (afronding bij optelling aan de referentie). Die kleine afwijking van de CONTACT47-schaduwsom is de werkelijke terugkoppeling op RATE-geometrie; het is geen gekopieerde voorspelling.

De referentie loopt in deze90 van 0.44400147057491446 naar 0.44400148840363196. Het begin verschilt al van de ouder doordat ook eerdere eigen main-cell stappen het contract gebruiken. S_active ligt tussen 0.0027555524949274303 en 0.003156999716837461. Reconstructie uit de eigen referentie en theta is exact. Een uitsluitend lokale vergelijking met de ouderreferentie bij dezelfde kandidaat-theta isoleert een S_active-toename van 8.21562858118e-5 tot 9.08274867050e-5. Dat is een algebraische gevoeligheidsdiagnose, geen extra fysieke run.

De eerste referentiewijziging treedt op bij commit1, de eerste gewijzigde volgende rate/werkelijke sorptie bij poging2. Iedere volgende head ziet de gecommitte referentie en klok van de voorgaande head. Bij de echte volledige celuitdroging op stap128 worden tau/ref/S_initial nog steeds nul; stap129 heeft geen sorptie en houdt nul. Geen klokwijziging.

## Eigen traject en inventaris

O0 2.1156417 s; O2 1.7645480 s. Beide normaal en ongecensureerd, met identieke numerieke tekstuitvoer buiten tijdmetingen. Dezelfde vaste observatiehorizon is bereikt op35797.49100000009: nu344 heads/344commits in plaats van360 bij de ouder. Er zijn2164 Newtoniteraties, bereik2..17; geen afwijzingen en geen gereduceerde commits. De oorspronkelijke adaptieve dt-regels zijn behouden; na de selectie kan het eigen dt-pad verschillen.

Alle344 actuele providerstamps zijn vers; elke hostacceptatie voldoet aan de bestaande criteria. Maximaal residu9.969285230324032e-7 (grens1e-6), absolute somresidu7.601551260486556e-6 (grens1e-5). Maximale stapinventarisfout1.3439337778818443e-8 cm; maximaal0.7601551164 van de bestaande dt*1e-5-grens. Geen verruiming.

Onafhankelijke voorraadverandering over het korte segment0.3159837707345869cm tegenover externe hoeveelheid0.3159838575680579cm: verschil -8.683347102467209e-8cm, binnen de bestaande opgetelde residuenvelop4.910000001505149e-6cm. Dit komt overeen met de som van de geaccepteerde stapresiduen. Cumulatieve ledgerincrementen sluiten op de geintegreerde rates aan tot hoogstens6.67e-16cm; domein-stapfouten blijven onder1e-13cm. Geen ontbrekend water door de referentiecorrectie aangetoond.

## Grenzen

Hard20 seconden per route, intern16, 512-commitcap en vaste horizon behouden. Twee routes; geen extra provider-/probe-evaluaties door de instrumentatie, geen brede campagne. Broncheckpoint voor beide builds/runs4bf3e9c12. Alle bronnen, binaire identiteiten, uitkomsten, traces en assessor zijn bewaard.

Dit is een beperkte implementatie- en feedback-PASS. De route bevat geen echte afwijzing: de nieuwe scratch-invalidering is wel geimplementeerd, maar rollback/directe kleinere retry en eigen nieuwe herstart zijn niet dynamisch gekwalificeerd. Ook andere contactregimes, piekcap, reductie, Darcy, perched en nulactueleopname zijn hiermee niet algemeen toegelaten. Geen volledige periode/BAL of canonieke promotie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS; B0/B1.12/canoniek/no-macrorelease onaangeraakt.

CONTACT47/CONTACT_CONTRACT.md en de daar genoemde primaire SWAP4-handleiding p106 Eq6.54-6.56 blijven contractautoriteit. RESULT.json, SAME90_FEEDBACK_AUDIT.csv en assess_feedback48.py bevatten de herhaalbare numerieke onderbouwing. EVIDENCE.json bindt het archief aan de bron-/resultaatcheckpoint.
