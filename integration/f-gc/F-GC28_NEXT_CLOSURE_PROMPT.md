# Executable next closure prompt: F-GC23

Start en voltooi een afzonderlijke Groundwater Coupling closure workunit:

**F-GC23 — SWAP5 Accepted Whole-Window Groundwater Response Tangent & One-Corrector Composition Qualification**

Gewone ChatGPT-chat, niet Work-mode.

Gebruik de GitHub-connector rechtstreeks.

Repository:

`abhedwig-cell/SWAP5`

## Nummering en branch

F-GC23 is semantisch gereserveerd door de gekwalificeerde F-GC16 implementation DAG voor:

`whole-window response tangent and one-corrector composition`

Recheck live dat geen F-GC23 branch/authority inmiddels door een andere uitvoering is aangemaakt. Als F-GC23 inmiddels bestaat, overschrijf of hergebruik die branch niet. Stop dan nummer-remediation en reconcileer de bestaande authority voordat je verdergaat.

Voorgestelde branch:

`work/f-gc23-whole-window-response-tangent-one-corrector-composition`

## Program authority

Recheck live:

`regie/f-rg03-post-ci59p-program-rebaseline`

Bij F-GC28-audit:

- SHA `aac2644149dda47282a25a39892c6dc808323dd0`
- tree `922f6f6bd9acf700d9d39a2aa5007597f3891b03`

F-RG03 houdt G05 in de frozen v1 denominator en staat voor de groundwater lane runtime/coupler-composition toe, maar verbiedt semantische herdefinitie van G01-G04, kernel-transacties, mass authority en soil-water solver internals.

## Current canonical

Recheck live `integration/f-ci-canonical` en start exact vanaf de dan actuele canonical head.

Bij F-GC28-audit:

- SHA `379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`
- tree `556221f62b4fde616981499eba68ef5460f5d83c`

## Doel

Sluit uitsluitend de eerste bounded dependency uit F-GC28:

**een production-bruikbare, provenance-bound accepted whole-window response tangent voor de restricted direct-groundwater coupling path, zodat de normale productiearchitectuur predictor + één corrector kan blijven.**

Dit is GEEN nieuwe groundwaterfysica.

Dit is GEEN RossFast production admission.

Dit is GEEN autorisatie om Full Richards-fysica, het common soil-water solver contract, kernel transaction semantics of G01-G04 contracts te wijzigen.

## Frozen semantics

De tangent die als groundwater coupling response wordt gepubliceerd moet semantisch betrekking hebben op de relevante accepted coupling-window mapping, niet slechts op:

- de laatste Newton-iteratie;
- één lokaal solver-substep;
- een terminal boundary relation zonder whole-window state evolution;
- een rejected candidate;
- een andere lineage dan de candidate waarop de coupling proposal berust.

Een local/terminal tangent mag nooit als true whole-window `dh_bottom_dq_bottom` worden gepresenteerd.

RossFast D1/D2 research semantics blijven research-only en mogen niet als bewijs voor production whole-window semantics dienen.

## Reconcileer eerst bestaande sensitivity authority

Audit current canonical minimaal op:

- `src/solver/mod_soil_water_solver_contract.f90`;
- production Full Richards/reference solver implementation;
- interface-sensitivity implementation en diagnostics;
- `src/runtime/mod_groundwater_predictor_corrector_window.f90`;
- F-GC16 frozen restricted composition plan;
- F-CI56 predictor-corrector canonical admission;
- F-GC28 final gap audit;
- relevante F-SI qualification/admission authorities voor interface sensitivity.

Current canonical bij F-GC28 bevat reeds een typed solver seam met:

- `request_interface_sensitivity`;
- typed `dh_bottom_dq_bottom`;
- availability/method provenance;
- `interface_sensitivity_backsolves` diagnostics.

Bepaal evidence-based wat de production Full Richards authority werkelijk levert en over welke tijd/lineage-semantiek die derivative geldig is.

## Hard semantic gate

Alleen als de bestaande production/reference sensitivity zonder contractwijziging correct kan worden samengesteld tot de vereiste accepted whole-window response, mag F-GC23 implementeren.

Als de huidige sensitivity slechts local/substep is of onvoldoende provenance heeft en de oplossing een wijziging vereist van een contract dat buiten F-GC wordt beheerd:

- wijzig dat contract NIET;
- persist `F_GC23_BLOCKED_BY_SOLVER_SENSITIVITY_SEMANTICS_DEPENDENCY`;
- leg exact vast welke owner dependency nodig is;
- lever daarvoor een bounded vervolgprompt.

Geen semantische rebranding om de gate te passeren.

## Vereiste production composition

Als de hard semantic gate PASS is, implementeer een dunne runtime/coupler-compositie die minimaal:

1. de sensitivity aan dezelfde committed origin en candidate lineage bindt als de coupling trial;
2. een `available/unavailable/invalid` status expliciet draagt;
3. stale, rejected of cross-candidate sensitivity nooit publiceert;
4. alleen een tangent gebruikt die voor de relevante whole-window response geldig is;
5. bij unavailable/non-smooth/invalid fail-closed blijft;
6. finite difference uitsluitend als reference/fallback route gebruikt;
7. geen structureel 6-9 volledige SWAP-runs per coupling window introduceert;
8. de normale predictor + corrector architecture intact laat;
9. geen mass-transfer semantics verandert;
10. geen acceptance/commit authority aan de tangent zelf geeft.

De tangent mag proposal/convergence acceleration ondersteunen. Acceptance blijft bepaald door de bestaande transactionele coupling authority en expliciete head/mass gates.

## Whole-window qualification cases

Kwalificeer minimaal:

- smooth reference cases waarin analytic/backsolve response tegen symmetric finite-difference reference wordt vergeleken;
- meerdere coupling-window lengtes, waaronder subdaily, daily-equivalent en non-calendar-aligned windows;
- candidate lineage mismatch;
- rejected predictor/corrector candidate;
- sensitivity unavailable;
- non-finite sensitivity;
- non-smooth/regime-switch case, die fail-closed of expliciet fallback moet geven;
- exact mass preservation vóór en na sensitivity use;
- O0/O2 identity voor de qualification harness;
- no hidden extra full-run multiplier in normal path.

Finite-difference runs zijn qualification/reference evidence, niet de productiearchitectuur.

## Transaction and provenance requirements

De sensitivity moet auditable zijn met minimaal:

- coupling_id;
- SWAP lineage/origin revision;
- candidate revision;
- `[t0,t1]`;
- derivative value;
- units;
- method/provenance;
- availability/status.

Een corrector vertrekt fysisch altijd vanaf de juiste committed checkpoint. Numerical warm-start mag alleen als startschatting dienen en mag derivative provenance niet veranderen.

## Mass conservation

Hard gate:

Sensitivity use mag de watertransfer niet veranderen of mass residual tolerance versoepelen.

`q_SWAP = -q_GW` blijft exact de transfer authority.

Een head residual binnen tolerance legitimeert nooit mass loss.

## Coupling cost

Bewijs dat de normal path niet structureel extra volledige SWAP-trajecten nodig heeft boven de frozen predictor + één corrector architecture.

Een backsolve uit bestaande Jacobian/factorization is gewenst waar dat de qualified solver authority reeds toelaat.

Als alleen finite-difference whole-window reruns mogelijk blijken, mag dat als fallback/reference worden vastgelegd, maar F-GC23 mag dan niet claimen dat de bounded production tangent closure volledig is.

## Architectuurtoets

Toets expliciet alle 30 SWAP Core Architecture Invariants.

Speciale aandacht:

- transactionele candidate lineage;
- generic time;
- flexible coupling windows;
- absolute mass conservation;
- first-class sensitivity semantics;
- bounded coupling cost;
- MultiSWAP compatibility;
- solver isolation;
- physics/policy separation;
- runtime/coupler ownership.

## Parallel-lane safety

Niet wijzigen:

- drainage physics;
- ET/root/surface physics;
- common soil-water solver ABI/contract;
- kernel transaction semantics;
- groundwater G01-G04 semantics;
- bounded-cost/performance policy owned door de PE-lane;
- RossFast research contract;
- frozen v1 denominator.

Als closure een dergelijke wijziging vereist, stop die remediation en persist de dependency.

## Evidence and qualification

Persist minimaal:

- machine-readable F-GC23 status;
- exact current-canonical SHA/tree;
- production source blobs;
- sensitivity semantic provenance;
- analytic/backsolve versus finite-difference evidence waar geldig;
- candidate-lineage negative tests;
- mass evidence;
- coupling-cost evidence;
- all-30 architecture audit.

Owner qualification alleen is niet genoeg voor G05 completion. Na een geslaagde owner workunit moet een onafhankelijke F-VQ qualification volgen en daarna een F-CI current-canonical admission/preservation cycle.

## Outcome A

Alleen als de whole-window semantics en bounded-cost production path werkelijk zijn bewezen:

`QUALIFIED_ACCEPTED_WHOLE_WINDOW_GROUNDWATER_RESPONSE_TANGENT_READY_FOR_INDEPENDENT_QUALIFICATION`

Geef exact aan dat dit nog GEEN volledige G05/end-to-end groundwater production admission is.

## Outcome B

Als de production semantics niet zonder cross-owner wijziging bewezen kunnen worden:

`F_GC23_BLOCKED_BY_SOLVER_SENSITIVITY_SEMANTICS_DEPENDENCY`

Geef dan:

- exact ontbrekende semantic capability;
- huidige source/authority evidence;
- owner van de dependency;
- minimale remediation;
- production source change YES/NO;
- independent qualification nodig YES/NO;
- canonical admission nodig YES/NO;
- volledig uitvoerbare vervolgprompt.

## Exit report

Rapporteer compact maar exact:

- workunit/branch;
- current canonical SHA/tree;
- production Full Richards sensitivity semantics;
- true whole-window tangent available YES/NO;
- candidate provenance PASS/FAIL;
- generic-window semantics PASS/FAIL;
- finite-difference reference comparison PASS/FAIL/NOT_APPLICABLE;
- normal predictor+corrector cost preserved PASS/FAIL;
- exact mass unchanged PASS/FAIL;
- fail-closed unavailable/non-smooth path PASS/FAIL;
- production source changed YES/NO;
- common solver contract changed NO;
- denominator changed NO;
- independent qualification required YES;
- next G05 composition step.

Geen overclaim. Geen local tangent als whole-window tangent presenteren. Mass conservation is absoluut.
