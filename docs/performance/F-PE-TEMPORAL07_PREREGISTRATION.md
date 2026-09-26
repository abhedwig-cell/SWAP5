# F-PE-TEMPORAL07 — c=0.65 coupling admission qualification

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent:
- F-PE-TANGENT01 / PR #651
- parent head at workunit creation: `b45f348757742b4993ec4a1af3bed038dd19b38c`

Frozen candidate policy:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

## Trigger

TEMPORAL05 blind-validated c=0.65 for state, q, flux and integrated exchange.

TEMPORAL06 showed a production-shaped retry/runtime gain but stopped because c=0.65 and c=0.50 published different tangents.

TANGENT01 resolved that ambiguity:

- c=0.65 fresh tangent matches the centered finite-difference derivative of the c=0.65 response map to about 1e-9 relative;
- c=0.50 likewise matches its own response map;
- c=0.65 corresponds to the N=1 accepted trajectory and c=0.50 to N=2;
- the difference from N=64 is temporal discretization of dq/dh, not a tangent implementation defect;
- the canonical fixed-interface contract requires accepted-trajectory d(q_swap)/d(H_interface).

Therefore direct tangent overlap with c=0.50 or N=64 is not an admission authority for the c=0.65 participant map.

## Purpose

Qualify c=0.65 for production coupling against the quantities that the admitted fixed-interface contract actually consumes:

1. accepted-origin q(H);
2. accepted-trajectory dq/dH for the same response map;
3. MODFLOW-facing affine relinearization built from that value and tangent;
4. coupled endpoint convergence and transaction/mass invariants;
5. production-shaped tangent-cache behavior.

No coefficient calibration is permitted.

## P0 — same-policy linear-response qualification

Primary difficult dynamic matrix:

- B01 wet;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid;

with accepted history imbalance -0.10 and +0.10.

For each origin:

- freeze c=0.65;
- disable tangent cache for authority measurements;
- evaluate fresh q(H*) and tangent T(H*);
- independently evaluate q(H* + deltaH) from the same captured origin;
- compare actual q to linear prediction q(H*) + T(H*) deltaH.

Preregistered deltaH ladder:

- +/-0.001 cm;
- +/-0.01 cm;
- +/-0.05 cm;
- +/-0.10 cm.

These are response-use perturbations, not finite-difference perturbations for tangent selection.

Report:
- absolute q prediction error;
- relative q prediction error;
- whether candidate temporal path changes;
- retries, temporal rejections and solver rejections.

P0 gates:
- all center and probe candidates complete;
- zero solver rejections;
- relative q linearization error <= 1% for +/-0.01 cm;
- relative q linearization error <= 2% for +/-0.05 cm;
- +/-0.10 cm is characterization only.

## P1 — production cache qualification

Enable existing production cache controls:

- head limit = 0.005 m;
- max age = 8.

Use the TEMPORAL06 64-request same-origin sequence.

Require:
- q identical to the cache-disabled policy response for the same request;
- reused tangent identical to the last qualified fresh tangent;
- refresh occurs only at admitted age/head/provenance triggers;
- no solver rejection or ownership change.

Cache behavior is a performance mechanism only. It cannot change q or accepted state.

## P2 — live MODFLOW6 coupled endpoint

Use the admitted one-SWAP/one-MODFLOW-cell fixed-interface closeout architecture.

The c=0.65 corrector response must be inserted through the existing physical relinearization contract:

`HCOF = A * 86400 * dq_swap/dH`

`RHS = HCOF * H* - A * 86400 * q_swap(H*)`

Qualification compares the coupled endpoint against an independent physical endpoint constructed without the production HCOF/relinearization path.

Frozen closeout authorities remain:
- same accepted SWAP origin for probes/correctors;
- rejected trials have zero authority;
- MODFLOW XOLD remains fixed inside the prepared solve;
- all preflights precede irreversible publication;
- publication order MODFLOW -> SWAP -> ledger;
- exactly-once interface mass publication.

P2 gates:
- coupled convergence;
- independent endpoint head error <= existing closeout tolerance;
- independent physical residual <= existing closeout flux gate;
- native MODFLOW model/component balance gates unchanged;
- accepted interface amount equals accepted SWAP transfer;
- no new solver rejection caused by c=0.65 policy.

## P3 — performance/admission interpretation

Only if P0-P2 pass:

- compare c=0.65 repeated-sequence retry/runtime to c=0.50;
- retain TEMPORAL06 measured performance evidence where lineage remains unchanged;
- explicitly state the admitted approximation: coarser accepted temporal trajectory may have a different dq/dH than finer Reference trajectories.

Production admission, if justified, must document that c=0.65 changes temporal discretization policy and therefore may change both q and its consistent Jacobian within the already-qualified physical error envelope.

## Stop conditions

Stop without admission if:
- same-policy q linearization fails the frozen P0 bounds;
- live coupled endpoint fails existing fixed-interface physical gates;
- mass or transaction authority changes;
- cache changes q or state;
- solver rejection appears because of the selected policy;
- production implementation would require changing coupling semantics.

## Scope exclusions

No change to:
- c=0.65;
- TEMPORAL04/05 physical bounds;
- BALTOL02;
- Richards equations;
- retry scale;
- tangent formulation;
- tangent-cache defaults;
- MODFLOW fixed-interface semantics;
- drainage/root-uptake admission boundaries.

Repository evidence decides admission.
