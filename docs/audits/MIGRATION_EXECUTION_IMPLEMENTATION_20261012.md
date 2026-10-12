# Implementatievolgorde en te behouden regels

**Status: Proposed**, voortbouwend op het
[onderzoek](MIGRATION_EXECUTION_ANALYSIS_20261012.md). Geen actuele workflow,
evidence, contract of tolerantie wordt door deze analyse veranderd.

| Prioriteit | Aanpassing | Type | Uitvoering en beoordeling |
| --- | --- | --- | --- |
| 1 | Kies één functionele productieroute en dependencyclosure per opdracht | Direct, geen code | Gebruik bestaande ownerstatus; kleine checkpoints zijn geen sessie-einddoelen. Begin met de RAINTB-proef |
| 2 | Hervat status-first, controleer exact delta en opgeslagen bronhash | Direct, geen code | Bestaand AGENTS/protocol toepassen. Meet herhaald onderzoek prospectief; geen nieuw repositoryregister |
| 3 | Reconcile ledger en canonical ownerreceipt bij afsluiting | Direct, geen code | Eerst warmte-dispositions door masterowner herstellen; geen stale ACTIVE als fysisch tekort tellen |
| 4 | Plan gedeelde sciencebesluiten vóór afhankelijke implementatie | Direct, geen code | Cropfase, Snow/layout, HY/grid en drainage/coupling blijven bestaande eigenaarwerk. Concrete beslissing en gates, geen generieke nieuwe commissieronde |
| 5 | Bundel documentaire closeouts; kwalificeer stabiele route | Direct, geen code | Gebruik bestaande docs/hashchecks en toegestane inheritance; exact admissionreceipt behouden. Brede rerun na relevante reparatie blijft verplicht |
| 6 | Bestaande runnercontrol uitbreiden met tijd/event/reason-for-rerun | Kleine tooling, apart | Voeg optionele proefmetadata toe aan owning status/log; old records niet retrofiten. Test provenance, interrupted/failed status en ontbrekende datums |
| 7 | Read-only dependencyselector in shadow mode | Kleine tooling, apart | Geef RUN/INHERIT/UNKNOWN-advies naast huidige gates; nog niets overslaan. Include/shell/generated/data/config/compiler/sourceguardclosure verifiëren; mutation-controls moeten gemiste dependencies afwijzen |
| 8 | Dubbele suiteoproepen en frozen inheritance automatiseren | Grotere kwalificatiewijziging | Pas na shadow validation en VQ/F-CI review. Cachekey omvat exacte transitive inputs, argumenten, omgeving, claim en authority. Originele logs/refs blijven immutable; moving gates blijven zelfstandig |
| 9 | Workflowtriggers en frozen/moving scheduling herontwerpen | Grotere kwalificatiewijziging | Afzonderlijke PR: changed-path en transitive-trigger tests plus checks-policy-review. Beoordeel push én PR, concurrency, mergecheckout en runnerimage. Meet jobcount/startdelay vóór en na; geen runnerbesparing claimen uit YAML alleen |

De historische [F-TA04 PR172](https://github.com/abhedwig-cell/SWAP5/pull/172)
benoemt bestaand F-TA02 impact-selectionwerk;
dit is niet als huidige canonical selector aangetroffen. Vóór een nieuwe tool
bouwen eerst de exacte branch/recovery en huidige admission reconstrueren.
Dubbele tooling ontwikkelen is geen procesverbetering. Ook CI-triggertriage bestaat
al in PROJECT-CONTROL; bouw daarop voort.

Prioriteiten 1-5 behoeven geen herontwerp van de wetenschappelijke gates en kunnen
binnen bestaande autorisatie worden toegepast. Het voorgestelde uitvoeringsmodel
is een concrete leeswijze van bestaande regels, geen automatische vervanging van
het protocol. Na de proef kan een korte verduidelijking van “small slices” versus
functionele werkpakketten in de bestaande workstreams/protocol worden voorgesteld.

Automatisch gates overslaan op basis van een selector is geen gewone administratieve
optimalisatie. Vereis daarvoor een afzonderlijke F-CI/VQ-beslissing, behoud een
conservatieve fallback en verifieer false-negative-impact met doelbewuste veranderingen
in directe én indirecte inputs. Vergelijk met de huidige brede suite; iedere
onbegrepen mismatch valt terug op RUN. Eén geslaagde proef bewijst geen algemene
architectuurneutraliteit of onveranderd regressierisico.

## Regels die intact blijven

Full Richards blijft de productie-/referentieroute; gecertificeerde referentietrajecten
en exact historische B0/B1/B2-bronautoriteit blijven geldig binnen hun scope.
Massabalansen, numerieke/temporal-toleranties en onafhankelijke oracles worden niet
versoepeld. State ownership, trial/accept/retry/rollback, rejected-state nonmutation,
restartcoherentie en exactly-once receipts blijven bindend.

De SWAP5-MODFLOW-contracten voor fysieke paths, heads, units/areas, donor-/storage-
ownership, mass en joint continuation blijven ongewijzigd. Relevante actuele
F-CI preservation, nieuwe-physics ownerkwalificatie, exact postimage-/mergetreecontrole
en reproduceerbare canonical admission blijven vereist. Evidence inheritance
blijft beperkt tot bewezen ongewijzigde relevante dependencies; onzekerheid is RUN.
Implemented, persisted, tested, qualified, preserved en admitted blijven afzonderlijk.

## Beslismoment na de proef

Beoordeel functionaliteit en veiligheid eerst, proceskosten daarna. Neem alleen
verbeteringen over waarvoor traceerbare besparing of vermeden duplicatie bestaat
en geen ongeadresseerde kwalificatiecoverage verdwijnt. Ongelijke scope of ontbrekende
historische arbeidstijd geeft INCONCLUSIVE, geen verzonnen winstpercentage.
Bij een fout door te late detectie verklein de bundle of voeg een focused gate toe;
bij een echte shared-contractblokkade verbeter readiness, niet de tolerantie.
Leg het besluit in de bestaande proef-/ownerreceipt vast en vervolg de eerstvolgende
dependency-ready productieroute. Geen nieuwe verplichte administratieve laag.
