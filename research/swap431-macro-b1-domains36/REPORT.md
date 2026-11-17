# DOMAINS36 — minimale analytische aanvulling afgebakend

**De resterende domeinbijdragen op dezelfde Jacobiaantoestand zijn ontleed.** Voor het onderzochte GWL-/verzadigde blok bestaat de afgebakende aanvulling uit twee rang-één-voorraadtermen voor domeinen 2 en 3, plus twee bestaande tridiagonaalcoëfficiënten op rij 51. De analytische schaduw verklaart vier gemeten headkolommen over alle 112 macroresidurijen met maximaal **1,229507051725420e-9** afwijking. Er is nog geen solvercorrectie ingevoerd.

## Basis en bewaard gedrag

Baseline is INACTIVE35 `7bc419d2d27696e0125ee2767e3d45326dca3c82`; remote onderzoeksbranch is gelijk. Remote main blijft `be481cfb40f953e337116ef4a6dc5bc3ef64d4f7`. De vaste eigen kandidaattoestand blijft poging 293, iteratie 30, na Jacobiaanopbouw en vóór TRIDAG, op t1900 35797,370324351359.

Alle bestaande numerieke exports, solverdumps, operatortraces, primitive budgetten, ledgers en het volledige geselecteerde snapshotsysteem zijn bytegelijk aan INACTIVE35. Ook de snapshot vóór de gevoeligheidsproef is exact dezelfde 20.347.880 bytes, SHA-256 `dcd762c36d16ec3dbd37117bbf22a2d658c5f33fb2460ba9ef369afbada45db6`. Er zijn alleen twee observatiebestanden uitgebreid: per-domeinrates/-grenzen worden gekopieerd en uitgelezen, zonder dat fysica of solver die diagnosecache gebruiken.

Twee modelroutes zijn vooraf vastgelegd: dezelfde transactionele TRIAL_PROBE met O0/O2, achttien echte MACRORATE-evaluaties en negentien herstellingen. Geen andere nodes, eps-waarden, context, solvervariant, periode of herstart. Iedere route heeft dezelfde twintigsecondenlimiet.

| Route | Normale procestijd, seconden |
| --- | ---: |
| O0 | 2,556195 |
| O2 | 1,932063 |

Beide stoppen normaal en ongecensureerd. Alle niet-timingtekstexports en attemptvelden zonder rekentijd zijn exact gelijk tussen O0/O2. Alle negentien geselecteerde toestandsherstellingen zijn bytegelijk; herkende IEEE-flags zijn hersteld en de baseline numerieke voortzetting blijft ongewijzigd.

## Welke domeinen dragen bij?

| Domein | FrIn | FrOut op basispunt | Actieve voorraadbegrenzing | Rol in deze diagnose |
| --- | ---: | ---: | --- | --- |
| 1 | 1 | 1 | Geen | GWL-afhankelijkheid gedeeltelijk verzadigde instroomcel 51; ontbrekende lokale interne-instroomafgeleide |
| 2 | 1 | 0,04420461997746161 | Minimumvoorraad, gedeeltelijk | Tweede niet-lokale voorraadnormalisatie |
| 3 | 1 | 0,8213966087076336 | Minimumvoorraad, gedeeltelijk | Eerder aangetoonde niet-lokale voorraadnormalisatie |
| 4 | 1 | 1 | Geen | Onbegrensde onverzadigde uitstroom; nul respons in de vier onderzochte kolommen |
| 5 | 1 | 1 | Geen | Onbegrensde onverzadigde uitstroom; nul respons in de vier onderzochte kolommen |

De eerder onverdeelde bijdrage aan J52,50 komt volledig uit domein 2:

| Macrobijdrage aan residu-J52,50 | Waarde |
| --- | ---: |
| Domein 1 | 0 |
| Domein 2 | +0,1053661976279990 |
| Domein 3 | +0,3409272299746343 |
| Domeinen 4 en 5 | 0 |
| Som | +0,4462934276026333 |

De som stemt overeen met de eerder direct gemeten totale macrorespons; het verschil in de laatste decimalen komt van het sommeren van centrale verschillen. Alle vijf afzonderlijke uitwisselingen sluiten op de oorspronkelijke totale uitwisseling. De potentiële vectoren en werkelijk toegepaste begrenzingsfactoren reconstrueren bovendien ieder domein afzonderlijk over alle achttien proefpunten.

## Ook domein 1 heeft een ontbrekende afgeleide

De eerste hypothese — uitsluitend twee voorraadtermen plus geometrie van cel 51 — laat een diagonale fout van ongeveer **0,02762944** over. De oorspronkelijke provider bevat op cel 51 zowel verzadigde matrixinstroom als interne verzadigde instroom. SATFLOW(4) gebruikt de lokale matrixinstroom in zijn bestaande afgeleide, maar niet die extra lokale interne-instroomterm. Ook de afgeleide van de gedeeltelijk verzadigde celfractie ontbreekt.

Het native GWL-volumecompartiment is 51; de drukheadinterpolatie blijft 50/51. De interne/perched zone heeft hier eveneens top en bodem 51 en dezelfde waterstand −66,56028506140325 cm. Deze waarden zijn zonder extra modeluitvoering uit de behouden SENSE23-snapshot gelezen; de WRITE-layout, gecompileerde dimensies, klok, dt en procesvolgnummer zijn gecontroleerd. Dit behoudt de bestaande providersemantiek; er is geen interne stroom verwijderd of fysiek geherinterpreteerd.

De resulterende aanvullingen binnen de bestaande tridiagonaal zijn:

- Rij 51, kolom 50: **+0,0037105477280693863**.
- Rij 51, kolom 51: geometrie **+0,013166512395977319** plus interne instroom **+0,027629440630022564**, samen **+0,04079595302599988**.

Dit zijn geen extra dense rijen of een nieuwe fysische flux. Zij vullen uitsluitend afgeleiden van de reeds gebruikte providertermen aan.

## Analytisch contract en toets

CONTRACT.md legt de actuele gegevens, tekens, guards en formules vast. In compacte vorm:

    Jnieuw = (Jbestaand_tridiagonaal + B51) + u2 v2^T + u3 v3^T

De voorraadtermen volgen uit f=(W+I−L)/O en df=(dI−dL−f·dO)/O. In de getoetste tak is de topinstroom constant, dL=rho·dG en de uitstroombasis lokaal in de verzadigde head. De bestaande directe lokale afgeleiden blijven behouden; zij worden niet nogmaals toegevoegd.

De twee voorraadtermen zijn hier niet identiek aan één rang-één-term: een relevante 2×2-minor is −1,514568503534415e-5. Een minimale uitvoeringsvorm kan de bestaande TRIDAG behouden voor de aangepaste tridiagonaal en twee aanvullende rechterleden, gevolgd door een 2×2-Woodbury-correctie. Dat is een ontwerp, geen geïmplementeerde of gekwalificeerde oplossing.

Met beide voorraadtermen en beide bijdragen in B51 stemt de volledige macroschaduw overeen met alle vier getoetste kolommen 50, 51, 52 en 57, alle 112 uitvoerrijen, beide centrale eps-waarden en O0/O2. Grootste absolute verschil: **1,229507051725420e-9**. Zonder de lokale interne-instroomterm ontstaat de genoemde fout van ongeveer 0,02762944.

## Geldigheidsgrens en besluit

Status: `MINIMAL_POINT_QUALIFIED_CONTRACT_TWO_STOCK_RANK_ONE_TERMS_PLUS_BANDED_DOMAIN1_GEOMETRY_AND_INTERNAL_INFLOW_DIAGONAL`. Het puntgebonden correctiecontract is onderbouwd; de solver is ongewijzigd.

Dit is geen kwalificatie van alle 112 inputkolommen of alle takken van de echte grote head. De bodem heeft dynamisch krimpbare bovenlagen; hun aanvullende geometrie-/oppervlaktekoppelingen zijn niet onderzocht. Voorraadcaps, exacte ties, veranderende zone-indexen en andere stroomrichtingen vereisen expliciete guard-/takbehandeling. Het contract benoemt die grenzen en stelt geen ongeteste volledige Jacobiaan of gegarandeerde convergentie voor.

De kleinste volgende stap is de afgebakende analytische aanvulling gericht implementeren en toetsen op dezelfde grote poging 293, met dezelfde eigen aanloop, oorspronkelijke criteria, O0/O2 en twintig seconden per route. De bestaande fysische rates en eerdere gekwalificeerde toepassingsgevallen moeten behouden blijven. Eventuele echte afwijzing vraagt opnieuw herstel/directe-retrybewijs; die weigering wordt niet afgedwongen.

B1 blijft `B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS`. Actieve-afwijzingskwalificatie, volledige periodebalans, eigen herstart en algemene solvertoelating blijven open. De bekende IEEE_DENORMAL-melding is in beide ruwe procesuitvoeren behouden; er wordt alleen herstel binnen de geselecteerde proefscope gekwalificeerd, geen volledige programma-IEEE-identiteit.

STATUS, RESULT, CONTRACT, TRACE_FIELDS, NATIVE_ZONE_CONTEXT, de alleen-lezen footeranalyse, bronpatch, volledige oorspronkelijke en nieuwe proefuitvoer, bron-/buildidentiteiten en de geverifieerde DOMAINS36_EVIDENCE.zip bewaren de reproduceerbare afbakening. assess_domains36.py leest bestaande uitvoer en voert geen modellen uit. Geen fysica- of solvercorrectie, brede campagne of officiële promotie. B0, B1.12, canonical en macroporiënvrije releasebasis zijn ongewijzigd.
