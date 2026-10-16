# Voorgesteld operationeel uitvoeringsmodel

**Status: Proposed**, gebaseerd op het
[onderzoek](MIGRATION_EXECUTION_ANALYSIS_20261012.md). Dit voorstel wijzigt geen
geldende admissionautoriteit. Het concretiseert AGENTS en het bestaande
[execution-protocol](../development/workstream-execution-protocol.md).

## Werkpakket en uitvoering

Kies uit de actuele masterqueue een nog ontbrekende **productieroute** en lees
de actuele canonical-eigenaarreceipt voordat een ACTIVE-rij als ontbrekende
implementatie wordt behandeld. Formuleer de sluitvoorwaarde als een aantoonbare
fysische uitvoering: invoer → echte geaccepteerde state/flux → vervolgstap →
retry/restart. Leg capabilities, bronhash, owner, vaste interfaces, acceptance
en volgende actie vast in het bestaande eigenaarrecord. Geen extra centrale index.

De maximale veilige omvang is de dependencyclosure binnen geaccepteerde
interfaces met een reproduceerbare eindgate. Bundel als hetzelfde fysische
traject, dezelfde eigenaar en dezelfde compositiegates meerdere deelstappen
verbinden. Splits als een onbesliste gedeelde semantiek, andere mass-owner,
restart-layout of afzonderlijke acceptanceautoriteit ertussen ligt. Een
compileprobleem, checkpoint of kleine testfout is geen automatische splitsreden.
Een nieuwe fysische optie houdt een onafhankelijke oracle, ook binnen een grotere PR.

Werk in drie samenhangende fasen:

1. **Readiness:** pin HEAD en bestaand recoveryrecord; vergelijk relevante delta;
   verifieer opgeslagen bronmanifest; ordende dependencies en gedeelde besluiten.
   Stop alleen de afhankelijke wijziging bij een echte contractblokkade.
2. **Bouwen en gericht testen:** persist betekenisvolle postimages vóór dure
   runs; test gewijzigde ownerfunctionaliteit op O0/O2 en negatieve invarianten.
   Ga automatisch verder. Houd één branch en bestaande status/evidence aan.
3. **Stabiele kandidaat en admission:** voer onafhankelijke owner- en vereiste
   compositie/preservationgates uit; erf uitsluitend geldig bewijs. Elke latere
   relevante wijziging invalideert de getroffen gates. Reconcile live canonical,
   verifieer expected PR-head/mergetree, admit begrensd en verwerk masterreceipt.

Breed kwalificeren gebeurt wanneer de hele gekozen route samenwerkt, plus eerder
wanneer een gedeelde scienceautoriteit dat vereist. “Eén kwalificatiecyclus” is
geen vrijstelling voor opnieuw testen na een relevante foutreparatie. Tijdens
ontwikkeling zijn owner/regressiechecks actief, zodat bundeling de tijd tot
foutdetectie niet onnodig vergroot.

## Beslisprocedure voor selectie en bewijshergebruik

| Klasse | Voorbeelden | Regel |
| --- | --- | --- |
| A: bij relevante wijziging opnieuw | Owner O0/O2, onafhankelijke historische oracle, mass, reject/retry/rollback, restart, gewijzigde trajectory/compositie | RUN voor gewijzigde nieuwe semantiek en alle getroffen downstream-claims |
| B: onveranderde dependencyclosure | Fixed-ref historische F-CI-job; eerdere bronidentiteit; ownerbewijs na uitsluitend documentaire successor | INHERIT alleen met terminal resultaat, exact inputs/omgeving en volledig aantoonbaar onveranderde closure |
| C: interface-/physicsafhankelijk | HY arithmetic/Jacobian/tangent, F-KT/state-layout, crop/root/frost, Snow timing, MODFLOW unit/area/donor/receipt en joint restart | RUN bij directe of transitieve impact; eigenaar bepaalt relevante suite |
| D: administratief/documentair | Admissionreceipt, capabilitybeschrijving, recoveryverwijzing zonder execution-impact | Docs/JSON/link/hashchecks; geen zelfstandige numerieke herkwalificatie |

Een padnaam onder docs/integration maakt iets niet vanzelf D. Workflows,
manifests, gegenereerde inputs, sourceguards en door de runner gelezen JSON kunnen
de uitvoering veranderen. Exacte sourcepins blijven fail-closed. Een nieuwe
bekende blob accepteren vereist sciencebewijs en bevoegde successor-admission.

De volgende procedure kan eerst handmatig, later met een read-only selector:

```text
pin candidate + tested SHA + current canonical
verify evidence artifact identity, terminal status and owning acceptance scope
for each required claim/gate:
    recover its complete transitive input closure and qualified environment
    include source, contracts, reference, fixture, runner, flags, generated input,
    config, test semantics, external package/compiler identity and owning admission
    if closure, identity, applicability or terminal result is uncertain:
        RUN; request owner adjudication if science authority is unresolved
    else if candidate/canonical delta intersects that closure:
        RUN affected gate and dependent compositional claims
    else if accepted authority permits inheritance:
        INHERIT with original SHA/artifact/hash and verified equivalence rationale
    else:
        RUN
require independent qualification for each new physical claim
require all mandated current composition/Full Richards/F-CI admission gates
reconcile exact proposed merge tree before admission
```

Een glob of alleen Fortran `use`-imports is geen volledige dependencyclosure:
shells, includes, generated drivers, data, config en source allowlists tellen mee.
Bij ontbrekende closure kies een conservatieve ruimere suite; geef geen reuse
vrij op basis van “geen src veranderd”. Gecertificeerde trajecten en bestaande
toleranties blijven exact. Een compiler-/runnerimageverandering vraagt afzonderlijke
compatibiliteitsbeoordeling of rerun, ook voor frozen jobs.

Bewijs wordt aan de relevante geteste postimage gebonden. Een documentaire
final-head verschilt soms van scientific-head; leg de ongewijzigde closure vast
en verifieer het voorgestelde integratieresultaat. Claim niet dat een numerieke
run op de final SHA plaatsvond als alleen dezelfde scientific blobs zijn getest.
Een moving gate kan zo nodig opnieuw moeten lopen; een fixed-ref job is geen
vervanging voor actuele fysische compositie.

## Recovery, scheduling en eigenaarschap

Bij hervatten: bestaand statusrecord → gepind HEAD → delta sinds checkpoint en
upstream → intersectie met dependency_surface → alleen incomplete of geïnvalideerde
actie. Controleer checkpoint/artifactidentiteit en laat gerichte sourcehashverificatie
staan. Brede source-reconstructie is alleen nodig bij ontbrekende of gewijzigde
identiteit. Voor grote connectoroverdracht verifieer lengte, blobs en gehele tree
vóór kwalificatie; #1200 toont waarom teksttruncatie geen veilig herstel is.

Nieuwe checkpoints krijgen de bestaande stagevelden en één next_action.
Een checkpoint stopt de sessie niet. Dezelfde sessie vervolgt tests, kwalificatie,
overlap, PR en handoff zolang geautoriseerd en uitvoerbaar. Geen achtergronduitvoering
beloven na een antwoord. Check bestaande Actions op exact head; geen duplicaat
dispatch voor beschikbaarheid. Publicatie met skip-ci is alleen passend als de
geldende autoriteit het toestaat en de nodige lokale gates al zijn voltooid;
workflowwijzigingen verdienen hun eigen trigger/selectieverificatie.

Ownership blijft “parallel where ownership is disjoint; serial where semantics
are shared”. Een eigenaar is een bestaande rol/workstream, geen nieuwe door dit
rapport benoemde persoon. Een gedeeld interfacevoorstel eerst aan de bestaande
integratieautoriteit, met concrete alternatieven en gates. Geen bronmodule van een
oude branch over een nieuw admitted owner heen kopiëren.

Menselijke keuze is nodig bij een expliciete governancegrens, onopgeloste
wetenschappelijke keuze, prioriteitsconflict of uitbreiding buiten gedelegeerde
scope. Routine retrieval, checkpoint, foutdiagnose en bestaande toegestane gates
vragen geen “go”. Tijdgebrek levert een duurzame next_action, geen kunstmatig
klein fysisch doel op.

## Prioritering en afsluiting

Prioriteer dependency-ready productieroutes met grote functionele relevantie,
bestaande bronautoriteit, begrensde interfaces en complete admissionmogelijkheid.
Los gedeelde enablementbesluiten met meerdere downstream-afnemers vroeg op;
houd hun besluitwachttijd gescheiden van uitvoeringskosten. Verklein geen risico
door alleen makkelijke capabilitycounts te kiezen. Reconcile reeds admitted
maar nog ACTIVE warmterijen als documentaire achterstand.

Na gatecompletion: verifieer live base en expected head, behoud peers, controleer
mergetree/sourceblobs, kwalificeer getroffen delta en geef één begrensde admissionreceipt.
Werk de bestaande masterrijen en resterende queue bij als onderdeel van dezelfde
afsluitronde of geef de exacte receipt aan de bestaande masterowner. Documentary
follow-ups kunnen gebundeld; canoniek merge-SHA kan pas na merge worden vastgelegd.
Verander geen volledige disposition als slechts een beperkt profiel is bewezen.
