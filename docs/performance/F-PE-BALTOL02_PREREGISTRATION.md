# F-PE-BALTOL02 — production admission of scaled Reference balance floor

Date: 2026-09-26

Status: `PREREGISTERED_ADMISSION`

Parent: `F-PE-BALTOL01` / PR #646

Parent head: `cb7d3c56b7deed3b4abc46d77e662dfdddbcda5b`

## Qualified authority

BALTOL01 qualified the Reference Richards balance-rate lower bound:

`tol_effective = max(tol_configured, 2.8e-16 cm / dt)`

for both compartment and total balance convergence criteria.

Qualification evidence:

- 240/240 difficult dynamic Reference-floor points complete;
- no strict 1e-12 success is lost;
- state and terminal-flux differences versus the strictest successful solution are negligible;
- TEMPORAL03 8/16/32 fixed-substep oracle is recovered on 32/32 difficult dynamic points;
- the single P2 terminal-flux refinement exception contracts at N=64;
- mass accounting remains complete and roundoff-scale.

Existing PUB-P2E06/P2E07 authority independently supports an approximately fixed integrated-depth numerical floor dominated by representable theta-state resolution.

## Admission objective

Implement the qualified lower bound in production Reference Richards request construction without changing user/configured tolerances themselves.

## Exact production rule

For a physical Reference solve with positive finite step duration `dt`:

- compartment balance tolerance:
  `max(configured_compartment_balance_tolerance, 2.8e-16 / dt)`;
- total balance tolerance:
  `max(configured_total_balance_tolerance, 2.8e-16 / dt)`.

Do not alter:

- absolute or relative head tolerances;
- ponding tolerance;
- mass acceptance tolerance;
- temporal-certificate budget;
- nonlinear iteration caps;
- backtracking policy;
- practical/A2C tolerance policy.

## Ownership

The scale belongs at the Reference solver request boundary where `dt` is known.

The immutable configured parameter tolerance remains unchanged. The effective request tolerance is derived per physical solve.

## Qualification gates

### G1 strict preservation

For steps where `configured_tol >= 2.8e-16/dt`, request values must remain bit-identical to the configured values.

### G2 scaled-floor identity

For steps below the numerical floor, only the two balance tolerances may change.

### G3 BALTOL01 replay

Reproduce:

- broad difficult 240-point completion;
- strict-overlap state/flux equivalence;
- P2/P2R oracle recovery.

### G4 canonical regression

Run canonical Reference, groundwater-coupling, restart, mass, solver and CI authorities relevant to the serialized Reference path.

### G5 scope guard

Practical Richards/A2C paths must retain their separately qualified tolerance behavior.

## Admission boundary

Production source changes are allowed only in this workunit and only after the rule above is frozen.

No temporal-policy change or surrogate work is included.

## Closeout

Admit only if all gates pass. Otherwise revert production code and close blocked.