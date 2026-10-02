# Maaiveldformuleringen: routebeoordeling en falsificatie

Datum: 2026-10-02  
Status: `BOUNDARY_SWITCHING_NOT_SUFFICIENT__UNIFIED_SURFACE_VOLUME_RETAINS_VALUE_FOR_MASS_OWNERSHIP__NO_PRODUCTION_ADMISSION`  
Canonical branch zoals gemeld door de base van PR #956: `integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329`.  
Besproken productie-oppervlakken: B1.10 HeadCalc, B110 dynamische bovenrand, solvercontract en TOP03 participant/receipt.  
Geraakte invarianten: 3, 7, 11, 13, 28 en 30.

## Uitkomst

De hypothese dat alleen de scherpe maaiveld-omschakeling de TOP03-uitval veroorzaakt, is gefalsifieerd voor de beproefde inundatiegevallen. De grensvoorwaarde kan aantoonbaar van type wisselen en zo de niet-lineaire opgave veranderen. Toch falen 66 trajecten terwijl elke evaluatie dezelfde opgelegde externe-headmodus houdt en geen enkele grensregimewisseling optreedt. In één werkelijk vastgelegd vastgelopen tijdstap is bovendien op de geïnspecteerde verzadigde tak geen wortel aanwezig doordat de residual over een nabij-verzadigde constitutieve K-sprong van `-0.071773641` naar `+0.108171709` cm/d springt. Een andere maaiveldbalans kan die ontbrekende wortel niet herstellen zolang zij dezelfde bodemdiscretisatie, constitutieve wet en opgelegde natte head oplegt.

Daarom wordt geen productionformulier of empirische weerstand gekozen. De lokale oppervlaktewaterbalans blijft een goede eigendoms- en massaboekhoudkundige architectuur voor koppeling met Ribasim. Zij is op zichzelf geen reparatie voor de aangetoonde Richards-oplosserblokkade. Een volledige falsificatie van iedere complementarity-, semismooth- of monolithische oplosser is niet uitgevoerd en wordt niet geclaimd.

## Huidige schakel en vergelijking van de residual

In de B110 dynamische provider bepalen forcing, vorige ponding en de kandidaatdruk de route. De relevante predicates zijn:

- atmosferische-headlimiet uit `q1 >= 0` en `q1 > emax`;
- flux versus head uit de verzadigde-headschatting `h0 <= 1e-6 cm`;
- ponding/runoff uit vergelijking van de ongeremde pondoplossing met `ponding_max`;
- externe inundatie wanneer externe head strikt boven de sill ligt en minstens de vorige pondhoogte is.

Bij flux-regime zet HeadCalc de eerste Richards-residual als een grensfluxterm. Bij head-regime gebruikt het de conductieve headgradiënt; de eerste Jacobiaanrij bevat de term `K/d * (1 - dHsurface/dh1)`. De routekeuze verandert dus de algebraïsche residual/Jacobiaan. `ftoph`, pondingdiepte en runoff zijn kandidaatwaarden binnen de solveriteratie; de gekoppelde owner mag alleen de uiteindelijke geaccepteerde transfer publiceren. Bij de externe-headroute wordt de lokale pondbalans overgeslagen.

Voor de natte, open en hydrostatisch verbonden grens geldt `Hsurface = HRibasim`. Als de lokale oppervlakte-CV en de continue interfaceconditie algebraïsch worden geëlimineerd, resteert precies diezelfde opgelegde head in de Richards-opgave. Dat is de limiet van een juiste verenigde surface-storage formulation bij bekende externe stage. De 66 no-switch-fouten zitten al in die limiet. Alleen door een eindige weerstand, niet-hydrostatische verbinding of ander bodemmodel toe te voegen, verandert die uitkomst; elk daarvan voegt een fysische relatie of parameter toe die afzonderlijk moet worden onderbouwd.

## Beoordeling van de alternatieven

| Formulering | Fysische en numerieke beoordeling | Bewijs en status |
| --- | --- | --- |
| A. Complementarity / semismooth | Geschikt om droge atmosferische toevoer, niet-negatieve oppervlakteberging en seepage-facecondities met één ongelijkheidssysteem te schrijven. Een semismooth methode kan het actieve stel oplossen zonder willekeurige drempelhysterese. Het verandert de natte opgelegde-headlimiet echter niet en verwijdert de interne K-sprong niet. | Literatuur ondersteunt de complementarityformulering voor seepage faces; dit is hier niet als nieuwe Richards-oplosser geïmplementeerd. Natte no-switch-geval blijft de beslissende falsificatie van boundary-only herstel. |
| B. Smooth/regularized overgang | Alleen zinvol met een fysische overgangsschaal en een aantoonbare limiet naar de oorspronkelijke grens. De lineaire externe-stage-ramp is geen epsilon-regularisatie, maar toont dat geleidelijker forcing de TOP03-trajecten niet algemeen redt. Het verwijderen van de nabij-verzadigde K-cutoff maakt die K-relatie continu, maar vergroot de uitval. | Stage-ramp: 33 tegenover 33 uitvallen voor constant versus abrupt in de matched gevallen; de ramp heeft 43 uitvallen. K-cutoff-counterfactual: oorspronkelijke Newtonpolicy 109→155 fouten; drukbewuste policy 80→126. Geen regularisatieparameter of production-default gekozen. |
| C. Verenigd lokaal oppervlakwater-CV | Dit is de duidelijkste eigendomsboekhouding: SWAP bezit lokale `Ssurf`, bodemtoestand en kandidaat `QRib`; Ribasim bezit zijn waterlichaam/stage en ontvangt `-QRib`. Voor geaccepteerde stap: `ΔSsoil = Isoil - Qbottom - ET - T + sinks`; `ΔSsurf = P + I + Melt + Runon + QRib - Esurf - Qrunoff - Isoil`. Sommeren laat `Isoil` exact weg. Publicatie van `QRib` gebeurt alleen na acceptatie; reject herstelt soil, `Ssurf` en het exchange carrier. | De balans elimineert dubbele boeking en adresseert TOP03-R2/R3 als interfacecontract. Voor permanent verbonden inundatie reduceert headcontinuïteit tot dezelfde opgelegde-headsolver die in 66 geen-switch-trajecten faalt. De huidige TOP03-resultaat/participant heeft daarnaast R4-R7 (window carrier, receipt-bypass, getypeerde head-resolutie en fallback-compositie) open. Dit CV is dus een architectuur voor accounting/coupling, geen gekwalificeerde solverreparatie. |
| D. Eindige oppervlakte-/contactweerstand | Verbetert de voltooiing van de specifieke stage-test bij `Rs >= 0.50 d`, ook op vlak oppervlak. Daarmee verandert ze echter de hydraulische interface en niet alleen de numeriek. De vereiste waarden zijn niet gelijkwaardig aan de beproefde expliciete dunne laag. | Bij `Rs=0.50 d` is het droge excessieve bodemuitvoer 0.04754 cm (8.97%) en ouder-headfout 0.2963 cm; bij `Rs=1.00 d` respectievelijk 0.08023 cm (19.54%) en 0.8210 cm. Gekwalificeerd als bounded counterexample; geen fysische parameterkwalificatie. |
| E. Alleen Newton-richting begrenzen | Verwijdert de waargenomen binnen-solve regimewissels, maar repareert geen van de 109 oorspronkelijke fouten bij cap 1. Cap 0.1 voegt 21 fouten toe. | Falsifieert een eenvoudige safeguard als algemene reparatie; geen volledige toets van complementarity- of semismooth-globalisatie. |

## Waar de aangetoonde blokkade zit

De sterkste lokalisatie komt uit één bevroren, daadwerkelijk gefaalde stap op de vrije-drainage ondergrens. Op het verzadigde-bovennode-interval `hbottom ∈ [-0.02, 0] cm` zijn de bovenste drie residualrijen lineair en exact geëlimineerd. Met de oorspronkelijke kandidaat-afhankelijke ondergrens-K en de bestaande constitutieve wet is de scalaire bottom-residual strikt stijgend op elk van de twee takken, maar springt zij over nul bij de K-cutoff rond `-0.01238604234 cm`:

| Taklimiet | Residual |
| --- | ---: |
| net onverzadigd | `-0.0717736410 cm/d` |
| net op verzadigde K-tak | `+0.1081717096 cm/d` |

De residualreconstructie uit de solverdump heeft maximale fout `0 cm/d`. Dit sluit een wortel uit op die tak en binnen dat interval; het sluit geen wortel op andere takken of elders uit. Meer Newtoniteraties of een direction cap kunnen een ontbrekende takwortel niet leveren. De K-continuïteits-counterfactual herstelt die sprong, maar introduceert meer uitval op de volledige bank. De blocker ligt dus niet uitsluitend in het maaiveldregime; hij omvat de interne nabij-verzadigde constitutieve/discrete Richards-opgave en de niet-lineaire oplossing daarvan.

De TOP03 koppeling zelf heeft daarnaast een aparte transactionele blokkade. Een enkel surface-CV maakt de externe balans ondubbelzinnig, maar kwalificeert niet automatisch accepted-window-accumulatie, reject/replay, top-active receiptverplichting, resolved-head materialisatie of geldige compositie van runoff/evaporatie. Die staan in `SW-RIB-TOP03_STATUS.json` als R2-R7.

## Testbank en begrenzing

De bestaande TOP03-testbank en archieven blijven de falsificatiebank; deze beoordeling voert geen nieuwe solver- of O0/O2-run uit en wijzigt geen productiebron. De bronnen en getallen zijn:

- `TOP03_SURFACE_TRANSITION_RESULT.json` plus `evidence/surface_transition/`: 702 trajecten per optimalisatie, 66 failures zonder regimewissel, 33/33 matched constant/abrupt failure counts en 43 failures bij de head-ramp; maximale gecombineerde ledgerresidual `1.8913e-13 cm`.
- `TOP03_FROZEN_ORIGIN_RESULT.json` plus `evidence/frozen_origin/`: residualbranch-gap en exacte dumpreconstructie voor de bevroren tak.
- `TOP03_CUT_COUNTERFACTUAL_RESULT.json` plus `evidence/cut_counterfactual/`: cutoff-verwijderingscontrole en regressies.
- `TOP03_NEWTON_GUARD_RESULT.json` plus `evidence/newton_guard/`: effect van direction caps.
- `TOP03_CONTACT_RESISTANCE_RESULT.json`, `TOP03_EXPLICIT_LAYER_RESULT.json` plus hun archieven: numerieke voltooiing versus fysieke transfervergelijking.
- `TOP03_CANONICAL_CONTACT_RESULT.json` en `TOP03_CANONICAL_CONTACT_DECISION.md`: componentreplay op een andere gepinde bronrevisie met een expliciet onadmitted ABI-patchvoorstel. Die replay is geen canonical-admissionbewijs voor `641a8ba7…`.

De switch-, cutoff- en guard-proeven zijn onderzoeksruns op hun vastgelegde source postimages; ze zijn geen actuele canonical-kwalificatie. De dynamic-top providerhash is gelijk tussen `641a8ba7…` en de transition-research pin `828df126…`; het verschil in HeadCalc betreft de expliciete macropore-providerroute, uitgeschakeld in de transition-bank. De externe inundatie-enable en candidate result discriminator zelf blijven branch-side wijzigingen en zijn nog niet canoniek toegelaten.

Een actieve TOP02-PR (#953) wijzigt dezelfde dynamische-top-provider en de bijbehorende TOP02 contracttests; PR #988 wijzigt eveneens HeadCalc. Daarom is in deze beoordeling geen gedeelde productiebron aangepast. Shared-semantic sourcewijzigingen moeten na die eigenarenreconciliatie serieel gebeuren.

## Literatuur en gevolg

De literatuur steunt geen algemene regel dat grensvoorwaarde-omschakeling verkeerd is. Scudeler et al. laten zien dat een dynamisch seepage-face/atmospheric-boundary-algoritme samen met oppervlakrouting de interactie kan oplossen, terwijl een statische Dirichlet-benadering in bepaalde natte/heterogene situaties fout gaat. Gatti et al. formuleren seepage als complementarity/ongelijkheden en lossen het als een vrije-grensprobleem op. Fiorentini et al. maken juist aparte oppervlakte- en bodemcontrol volumes en laten zien dat tijdslaging en flux-interpolatie de gekoppelde massafout beïnvloeden. Dit ondersteunt complementarity als mogelijke numerieke implementatie en een lokale surface CV als passende massaverantwoordelijkheid; het ondersteunt niet dat die veranderingen de hier vastgelegde ontbrekende Richards-takwortel oplossen.

Bronnen: Scudeler et al. (2017), DOI [10.1002/2016WR019277](https://doi.org/10.1002/2016WR019277); Gatti et al. (2024), DOI [10.1016/j.cma.2024.117368](https://doi.org/10.1016/j.cma.2024.117368); Fiorentini et al. (2015), DOI [10.1002/2014WR016816](https://doi.org/10.1002/2014WR016816).

## Besluit

Resultaat 2 geldt binnen de onderzochte TOP03-failure bank: boundary-switching/smoothing op zichzelf lost het TOP03-probleem niet op. Een local surface CV is de voorkeursarchitectuur voor exactly-once mass ownership in de koppeling, maar moet naast — niet in plaats van — een source-consistente oplossing of ander gekwalificeerd Richards pad bestaan. Er is geen nieuwe grenswet, tolerantie, weerstand, parameterdefault of productiecode gekozen.

De gerichte vervolgvraag is: kan een source-consistente Richards-discretisatie/oplosser hetzelfde natte, no-switch TOP03-interval door de nabij-verzadigde tak-overgang brengen, met huidige soil physics en massa-eigendom behouden? Pas als dat interval convergent is, kan de surface-CV transactionele kandidaat zinvol end-to-end met Ribasim worden gekwalificeerd.
