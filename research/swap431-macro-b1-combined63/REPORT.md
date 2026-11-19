# COMBINED63 — gecombineerde domein3-Jacobiaan werkt op dtmin-retry

De minimale COMBINED62-aanvulling is geïmplementeerd. De oorspronkelijke grotere D2-vervolgpoging wordt nog geweigerd; de normale retry op dtmin convergeert nu in3 iteraties en krijgt één ongereduceerde hostcommit. O0/O2 leveren dezelfde fysieke toestand, residuals, ledger en hetzelfde eigen vervolgcheckpoint. Fysica en budgetregels zijn behouden.

## Eindresultaat

| Eindroute | Rekentijd | Grotere poging | dtmin-retry |
|---|---:|---|---|
|O0|1,418 s|30iter, echte weigering|3iter, fresh controle, hostcommit|
|O2|1,229 s|30iter, echte weigering|3iter, fresh controle, hostcommit|

dtmin=1e-5 dag. Eind-Fmax=3,044456621352498e-8 cm/dag op node57, onder1e-6. SomF=2,0918085756152195e-7 cm/dag, onder1e-5. IDecMpRat0, FrReduQ1, geen fluxreductieverzoek of uitgevoerde numerieke fluxreductie op de geaccepteerde stap. De originele fysieke minimumvoorraadbegrenzing blijft actief.

De tijd wordt35797.290441125151; de gewone TimeControl stelt de volgende dt op2e-5 maar die volgende stap is niet uitgevoerd. De harness stopt op NATIVE55_RESTART_ONE_FULL_STEP. Dit kwalificeert precies één normale kleinere retry vanuit de oorspronkelijke checkpoint, niet de hele grotere poging of een vervolgtraject.

## Implementatie en guards

Baseline COMBINED62 fa93695fcc509c99aa2ec3d34851e968d0138b7c. Eerste implementatiecheckpoint526fa80be; actuele payloadcorrectie a8a3ed531. Onderzoekscode onder research/, geen productie-/Status-A-wijziging.

De actuele provider levert een nieuwe seq-gestempelde numerieke scratchpayload van sat-/uns-potenties vóór de lokale derivativetaken. De getter controleert taak/sequence/t/dt/poging/iteratie en alle heads. Geen gebruik van ongestempelde sample46 of ownerlog. De serializeruitbreiding betreft interne onderzoeksscratch/cache; er zijn geen native fysieke velden toegevoegd en de oude native-V6-code blijft byte-identiek. Oude debug/calibratiesnapshotcompatibiliteit is niet geclaimd; de gekopieerde legacy-calibratiefile wordt door de gekozen routes niet gebruikt.

jac63_terms valideert de COMBINED62-envelop en construeert alleen de ontbrekende factor- en contact-/vochttermen. De zeven verzadigde D3-diagonalen blijven eenmaal in de bestaande Jacobiaan staan. De nieuwe solve gebruikt de bestaande tridiag/rang2-Woodbury-werkwijze en dezelfde singulariteitsgrens als JAC37. Gedetailleerd contract en grenzen staan in IMPLEMENTATION_CONTRACT.md; sourcepatches en alle werkelijk gebruikte A/r/U/V/x zijn behouden.

Geen wijziging aan constitutieve SATFLOW/ABSORPTION/VOLUNDR, sorptieklok, hostintegratie, fysieke native-layout, dt, criteria, MAXIT30/60, vier backtrackingproeven, DTMIN58-update, reductiebeleid of interne16s/512commit/4retrybudgetten. De oude JAC24/37-guards zijn niet versoepeld. De onderzoekscontextgate is expliciet beperkt tot de oorspronkelijke opgeslagen vervolg-tijd; dit is geen algemene solverpromotie.

## Eerste payloadfout behouden en gecorrigeerd

De eerste twee O0/O2-routes waren normaal/ongecensureerd in2,330/1,456 s, maar de aanvulling werd alleen op W-punten actief. Oorzaak: de eerste getter las de live onverzadigde potentiewerkarray ná ABSORPTION(2), die die array initialiseert. Op V ontbrak daarmee de potentie; de guards wezen toelating terecht af. Die uitkomst is geen numerieke onderbouwing voor het weglaten van de V-term.

De oplossing is uitsluitend een levensduurcorrectie: bewaar de complete actuele D3-potenties vóór de destructieve derivativetaak in een eigen payload en herstel die samen met het seq-stempel. Er is geen guard verruimd, parameter afgestemd of criterium veranderd.

De eerste bronnen, identities, builds, ruwe routes en native-binaries zijn bewaard onder initial_source/, INITIAL_* en data_initial_payload_guarded. Daarna zijn twee expliciet geregistreerde eindroutes in een aparte workfolder uitgevoerd. Totaal4 modelroutes, alle normaal en onder20s per route; geen brede campagne of nieuwe context.

Causale controle: de gehele grotere-pogingregistratie en de eerste25 gecorrigeerde lineaire systemen zijn exact gelijk vóór/na de payloadcorrectie. Het verschil ontstaat pas wanneer de normale retry in de V-tak komt. Er is dus geen verborgen retuning achter de convergentieverbetering.

## Actuele solves en echte rollback

De eindroutes hebben27 actieve aanvullingen:24 W in de grotere poging en vervolgens W/V/V in de retry. De6 andere grotere-pogingproviders vallen correct terug: hun onverzadigde D3-uitflux ligt boven de originele1e-7-gate waardoor de oude lokale U-derivative al actief is. Dat valt buiten de gekwalificeerde afwezige-lokale-U-envelop; er is niet blind opgeteld.

De grotere poging blijft na30 iteraties op Fmax2,1198336748706748e-3/som8,414477305576075e-3, node52. Voor de retry zijn alle native-contextvelden exact gelijk aan het begin behalve de normale dt/fldtmin; de ledger is byte-identiek. Dit kwalificeert het werkelijke herstel van die afgewezen grotere poging, geen onafhankelijke directe-kleinere-retryvergelijking.

Alle27 echte (A+UVᵀ)x=r-systemen zijn onafhankelijk met112 componenten nagerekend. Maximale lineaire afwijking9,432558900623889e-18. De onafhankelijke domein3-kolomsomcontrole inclusief de bestaande lokale diagonaal sluit tot1,14e-13. De Woodburydeterminanten van de drie retry-solves zijn ongeveer0,9981,374,4583 en376,2887; er is geen actieve solverfout of fallback nodig. Dit bewijst geen algemene conditionering of portable prestatiewinst.

## Onafhankelijke waterinventaris van de hostcommit

Voorraadverschillen zijn rechtstreeks uit theta/dz/matrixfractie en alle macrocompartimenten berekend. Macro_sat en macro_compartment zijn hier alternatieve representaties en worden niet bij elkaar opgeteld. Externe nettoflux is zelfstandig uit de ongewijzigde host-budgetkolommen geïntegreerd; pond en canopy zijn expliciet meegenomen.

| Grootheid | Delta/integratie [cm] |
|---|---:|
|matrixvoorraad|-2,2257545273197916e-6|
|macrocompartimentvoorraad|-6,358490123801715e-7|
|pond / canopy|0 / 0|
|externe nettoflux|-2,8616056316129105e-6|
|inventarisfout|+2,0919129474248157e-12|

De bestaande grens is dt*CritDevBalTot=1e-10 cm. De inventarisfout ligt daaronder en verschilt slechts1,0437e-16 cm van somF*dt. De grootste afzonderlijke domeinfout is1,0751e-16 cm. Geen budgetregel gewijzigd om dit te laten slagen.

Er is precies één hostcommit en één ledgerintegratie. Het eigen follow.end is139128 bytes en byte-identiek O0/O2, SHA2567df2ffc6fd0ef85c129a9b91259bfa9baa0c234665a1b8e1d9cadb2f56d2e09e. Het bestand is geschreven, niet opnieuw in een vers proces gelezen in deze unit.

## Status en herstel

Gekwalificeerd: minimale actuele/payloadgestempelde rank<=2-aanvulling, beide takken werkelijk gebruikt, geen dubbeltelling, lineaire solves, fresh gekoppelde dtmin-convergentie O0/O2, werkelijke grotere-pogingrollback en één hostcommit met onafhankelijke waterinventaris. Geen providerperturbaties uitgevoerd; eerdere afgeleideprobes/ownerlogs zijn in de eindroutes uitgeschakeld.

Niet gekwalificeerd: convergentie van de grotere poging, geforceerde afwijzing met actieve V-correctie en directe kleinere retry, onafhankelijke fresh eigen follow.end-herstart of continue-vergelijking, algemene ondersteuning, hele balansperiode/BAL of B1-promotie. B1 blijft B1_CANDIDATE_WITH_EXPLICIT_EXCLUSIONS.

Volgende gerichte kwalificatie kan afwijzing/herstel/directe-retry-equivalentie of een korte eigen native herstart onderzoeken, binnen hetzelfde oorspronkelijke domein en dezelfde grenzen. Er is hier geen extra traject gestart.

Herstel: STATUS/RESULT.json, IMPLEMENTATION_CONTRACT.md, CONTRACT.md, LINEAR_AUDIT.csv, ITERATION_PROGRESS.csv, actuele patches, CODEX_FOLLOWUP.md, behouden initiële routes/bronnen en ruwe einduitvoer. assess_combined63.py start geen modellen. Een postprocessingkolomindex voor FrReduQ is gecorrigeerd en bewaard in ANALYSIS_NOTE.json; ruwe modeluitvoer is niet gewijzigd. EVIDENCE.json bindt de volledige initiële/eind-bewijzen aan een streaming-gecontroleerd archief.
