# INACTIVE51 - rollbackcontract voor inactieve sorptiehistorie

Het contract is afgebakend: bij afwijzing moeten ThtSrpRefDmCp en SorpDmCp exact terug naar de waarden van de geaccepteerde oorsprong, ook bij een inactief event. De minimale ontbrekende aanvulling is tijdelijke opslag en herstel van deze twee arrays in de bestaande MACROSTATEVAR(1)/(2)-transactie. Er is nog geen reparatie geimplementeerd; de huidige rollback faalt dit striktere historiecontract.

## Waarom opnieuw initialiseren de restauratie niet vervangt

De huidige ABSORPTION-code neemt bij Time<1e-8 de nieuwe-eventtak. Zij zet eerst de theoretische referentie op theta_s en berekent S_initial uit de actuele verzadigingsdeficietformule, en gebruikt daarna die nieuwe sorptiviteit. Oude inactieve waarden dragen in deze tak niet bij aan de nieuwe sorptiehoeveelheid. Bij geen geschikte sorptie/contact is deze initialisatie niet nodig voor een actieve bijdrage. Dit verklaart de in SELECT50 bewezen directe retry-equivalentie.

Beide waarden zijn ook opgenomen in de bestaande native state. Een geaccepteerde oorsprong heeft daarmee concrete opgeslagen referentie-/sorptiviteitswaarden, zelfs wanneer tau0 ze voor de eerstvolgende nieuwe-eventformule buiten werking stelt. Een afgewezen proef hoort die waarden niet als nieuwe geaccepteerde toestand terug te geven. Het gekozen contract eist daarom exact herstel van de oorsprong, zonder een algemene nulconventie voor inactieve velden in te voeren. De onderbouwing is toestandseigendom en reproduceerbare inspectie; er is geen ontbrekend water of afwijkende fysieke retry in D2 aangetoond.

## Toets in dezelfde oorspronkelijke D2

Prebuild observerbron3ec00a631, baseline SELECT50 f90b871d31a41f624d92abe1fb236c7395ed5015. Alleen dezelfde oorspronkelijke SELECT28-D2 (oude3066), t35797.290420649493,dt2.8284271247461902e-4. Twee nieuwe TRIAL-routes O0/O2, geen nieuwe contextselectie of DIRECT-run. De laatste wordt geerfd uit het verzegelde SELECT50-bewijs, omdat de volledige nieuwe TRIAL-uitvoer buiten timing bytegelijk blijft en de numerieke bronnen ongewijzigd zijn. Het parentarchief en manifest binden deze overerving.

De nieuwe bron bevat uitsluitend een receipt van bestaande pre-/post-eventinitialisaties. Geen extra provider, proef, vergiftiging van scratchwaarden, rollback-/referentiewijziging of gevoeligheidspunt. De assessor verwijdert de observerdelta en vergelijkt alle Fortran-bronnen exact met SELECT50. De nieuwe O0/O2-receipts zijn eveneens bytegelijk.

Alle614 receipts hebben exact tau0. Iedere referentie is voor sorptieberekening vervangen door theta_s en iedere beginsorptiviteit exact gereconstrueerd uit SorpMax*((theta_s-theta)/(theta_s-theta_r))**SorpAlfa. De oude referentie varieert in de waarnemingen tussen0 en.444;470 van614 beginsorptiviteitswaarden worden door een andere, opnieuw berekende waarde vervangen. Geen claim over willekeurige NaN-/ongeldige staten of andere eventregimes.

| Poging | D3/node50 initialisaties | D4/node49 initialisaties |
|---|---:|---:|
|1, afgewezen|119|123|
|2, afgewezen|68|136|
|3, afgewezen|54|106|
|4, geaccepteerd|0|8|

Per rollback blijven alle TimAbsCumDmCp- en AwlCorFac-waarden exact gelijk aan de oorspronkelijke toestand. De enige gewijzigde referentie-/sorptiviteitslocaties zijn D3/node50 en D4/node49, steeds met tau0 voor en na rollback. De referenties blijven0->.444, uitsluitend eventinitialisatie; de afgewezen CONTACT47-increment wordt niet gecommit. De CONTACT47-cache is na alle drie rollbacks ongeldig en nul. De ledger blijft tot acceptatie gelijk.

Er zijn dus per rollback vier exacte-herstelverschillen (twee arrays, twee locaties); over de drie rollbacks12 schendingen van het gekozen historiecontract. Reeds actieve histories blijven intact. De volledige solverketen, retries, geaccepteerde/committed toestand, waterinventaris en cumulatieven blijven gelijk aan SELECT50 en aan diens directe kleinere vervolg. Dat is functionele continuiteitsonderbouwing, geen bewijs van exact herstel van de inactieve velden.

## Minimale reparatiegrens

ROLLBACK_CONTRACT.md specificeert de toekomstige aanvulling:

- Bewaar ThtSrpRefDmCp en SorpDmCp voor alle betrokken domeinen/cellen op de geldige geaccepteerde saved-stategrens, na eventuele native restore en voor de eerste proef.
- Herstel beide exact bij afwijzing, voordat een nieuwe retry-snapshot wordt genomen. Hardcode geen D3/D4, node49/50 of tau0-test; oorsprongwaarden hoeven niet nul te zijn.
- Laat de klok en event-/CONTACT47-commitregels ongewijzigd. TimAbsCumDmCp wordt tijdens providers in deze code niet geschreven en is hier al exact; er is voor deze minimale correctie geen extra klokbuffer nodig.
- Gebruik uitsluitend tijdelijke transactiebuffers. De twee arrays zitten al in het native formaat; geen nieuw persistent veld of formaat nodig.

FlEndSrpEvt/FlSorp en rates/derivatieven zijn herberekenbare providerwerkvelden. CONTACT47-delta/mask/stamp worden ongeldig gemaakt, niet als geldige vorige rate teruggezet. AwlCorFac verandert in de afgewezen D2-proeven niet. De separate dynamische geometrie-/fluxhulpen VlMpDyCp/SubsidCp en boundaryhelpers blijven buiten dit sorptiehistoriecontract. Deze aanvulling is dus nog geen volledige native-snapshot-rollback of herstartcontract.

## Rekentijd en grens

O0:17.9989953s; O2:11.5188998s. Beide normaal, ongecensureerd en onder de externe harde20s, inclusief reconstructie van dezelfde oorspronkelijke1309commitprefix. Geen route is herhaald om een gunstiger tijd te verkrijgen. O0/O2 fysieke/niet-timinguitvoer exact gelijk aan de ouder en elkaar; alle oorspronkelijke residu-/inventaris-/retrycriteria behouden.

De bestaande interne16s-stoplogica is bytegelijk behouden. O0 registreert bij de terminale geaccepteerde commit17.0280577s sinds de interne start; O2 10.853379s. De originele driver sluit op die terminale acceptatie af voordat hij de teruggegeven done-indicator als een andere stopreden zou gebruiken. De16s-check is daarmee geen strikte wandklokgrens voor een al afgeronde terminale acceptatie. Er wordt geen strikte16s-runtime-PASS geclaimd en er is geen budgetregel versoepeld. De door de gebruiker gevraagde harde20s-grens is in beide routes gehaald.

## Status en uitsluitingen

De opdracht tot afbakening is afgerond: het ontbrekende eigendom van twee opgeslagen historiearrays is vastgesteld, de beperkte herberekenbaarheid is aantoonbaar, en de huidige implementatie is tegen het expliciete herstelcontract beoordeeld als FAIL. Exacte restauratie zelf is nog niet geimplementeerd of gekwalificeerd. Geen nieuwe herstart/fullperiode/BAL, geen algemene ongeldige-staat-/contactregimetoelating en geen brede campagne. B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS, geen promotie; B0/B1.12/canoniek/no-macrorelease onaangeraakt.

Veilige vervolgstap is een afzonderlijk geautoriseerde minimale saved-stateaanvulling van deze twee arrays met dezelfde D2-rollback/directretrytoets. Bewaarde SOURCE/OBSERVATION.patch, RESULT.json, TRACE_FIELDS.json en assess_inactive51.py geven de onderbouwing; EVIDENCE.json bindt het verzegelde bewijs.
