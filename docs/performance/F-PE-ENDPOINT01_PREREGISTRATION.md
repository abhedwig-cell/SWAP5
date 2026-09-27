# F-PE-ENDPOINT01 — dynamic-origin independent endpoint authority

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent:
- F-PE-TEMPORAL07 / PR #652
- parent head at workunit creation: `2b070aa9684bfc11ad8ab898132132106f44dae9`

## Trigger

TEMPORAL07 established that both c=0.65 and c=0.50:

- converge in the admitted live one-SWAP/one-MODFLOW-cell architecture;
- close the production q_swap/q_groundwater residual to about 1e-22 m/s;
- satisfy the frozen independent endpoint-head tolerance;
- satisfy native MODFLOW model/API component balance;
- preserve rejected-trial, publication-order and exactly-once mass invariants;
- fail the inherited independent physical residual gate at essentially the same value, about 2.735e-14 m/s.

The failure is therefore not attributable to c=0.65.

The historical independent endpoint authority constructs a local q_groundwater(H) relation from three constant-flux MODFLOW probes at:

- -2e-8 m/s;
- 0;
- +2e-8 m/s;

then linearly extrapolates that fitted q(H) relation to the physical endpoint.

For the dynamic O14-mid origin the accepted exchange is about 1e-7 m/s, roughly five times outside the positive probe magnitude.

ENDPOINT01 determines whether that extrapolation remains a valid residual authority.

## Purpose

Build an independent endpoint authority that does not require extrapolating a fitted q(H) law beyond its sampled exchange range.

The workunit is research-only.

No change is permitted to:

- c=0.65;
- c=0.50 comparator;
- SWAP equations;
- MODFLOW equations;
- fixed-interface coupling semantics;
- tangent formulation;
- cache policy;
- production convergence tolerances;
- endpoint-head acceptance tolerance;
- physical residual acceptance tolerance.

## P0 — groundwater response curvature characterization

Use the admitted one-cell MODFLOW6 6.8.0 closeout model and accepted dynamic O14-mid reference head.

Construct fresh constant-flux MODFLOW solves at a preregistered exchange ladder:

- -1.50e-7 m/s;
- -1.00e-7;
- -5.00e-8;
- -2.00e-8;
- 0;
- +2.00e-8;
- +5.00e-8;
- +1.00e-7;
- +1.50e-7.

Record H(q) for every point.

Compare:

1. the historical local three-point q(H) fit based on -2e-8, 0, +2e-8;
2. a fit over the full ladder;
3. direct interpolation/inversion of H(q) in the neighborhood of the physical endpoint.

P0 is descriptive. No admission decision is made from fit preference alone.

## P1 — direct constant-flux coupled endpoint authority

For each temporal comparator separately:

- c=0.50;
- c=0.65;

use the same captured O14-mid dynamic origin with history imbalance -0.10.

Define an independent scalar residual in groundwater-flux coordinate q:

1. run a fresh constant-flux MODFLOW solve with imposed q;
2. obtain the resulting one-cell hydraulic head H_gw(q);
3. run one non-committing SWAP corrector from the same captured origin at H_gw(q);
4. evaluate
   `R(q) = q_swap(H_gw(q)) - q`;
5. discard the SWAP candidate.

No production HCOF/RHS or production coupled iteration is used in this independent root.

### P1 bracket

Center the initial q bracket on the SWAP response at the accepted dynamic-origin head:

`q_center = q_swap(H_origin)`

Initial half-width:

`max(2e-8 m/s, 0.25 * abs(q_center))`

If R does not change sign, expand the half-width symmetrically by factor 2.

Maximum expansions:

`6`

No root is accepted if no sign change is found within that frozen search policy.

### P1 solve

Use bisection in q.

Independent endpoint passes only when:

`abs(R(q_root)) <= 1e-15 m/s`

This is the existing frozen physical residual gate. It is not changed.

Record:

- q_root;
- H_root;
- independent residual;
- bisection count;
- MODFLOW iteration counts;
- SWAP transaction path;
- committed-state invariance.

## P2 — production endpoint comparison

For c=0.50 and c=0.65 separately, compare the already qualified production coupled endpoint against the direct P1 endpoint.

Frozen gate:

`abs(H_production - H_direct) <= 5e-10 m`

Also evaluate the direct independent residual at the production endpoint by independently inverting H_gw(q) for that head, without the historical q(H) line fit.

Frozen gate:

`abs(q_swap(H_production) - q_gw,direct(H_production)) <= 1e-15 m/s`

No endpoint tolerance is changed.

## P3 — historical-closeout preservation

Run the direct endpoint authority on the historical canonical one-cell closeout fixture.

Require:

- the direct oracle itself reaches <=1e-15 m/s residual;
- its endpoint agrees with the historical closeout independent endpoint within 5e-10 m;
- no production coupling source is changed.

This prevents replacing a useful historical authority with a dynamic-only special case.

## Decision logic

### A — direct authority passes dynamic endpoints

If both c=0.50 and c=0.65 pass the direct independent residual and endpoint-head gates:

- the TEMPORAL07 blocker is diagnosed as q(H)-fit extrapolation / endpoint-oracle resolution;
- the historical three-probe line-fit residual is not a valid dynamic-origin admission authority outside its qualified probe scale;
- qualify the direct constant-flux endpoint oracle for dynamic-origin admission evidence;
- return to c=0.65 admission without changing the frozen physical gates.

### B — c=0.50 passes, c=0.65 fails

The selected c=0.65 policy is rejected for production coupling.

### C — both fail direct authority

The blocker is deeper than q(H) fit extrapolation. No c=0.65 admission.

### D — historical preservation fails

No oracle replacement is admitted. Investigate the discrepancy separately.

## Scope exclusions

No production source modification is authorized in ENDPOINT01.

Any later production temporal-policy admission is a separate write after ENDPOINT01 closure.
