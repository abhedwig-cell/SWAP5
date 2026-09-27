# F-PE-LIVE01 P1 preregistration — exact-trial directional cost bound

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-LIVE01 P0`

## Trigger

P0 localized the current exact live workload to:

- 32 exact SWAP trials across 12 difficult live groups;
- 20 temporal retries;
- zero solver rejections;
- zero internal retries;
- 236 nonlinear iterations / Jacobian builds;
- 380 linear solves;
- 72 headcalc calls.

P0 does not yet identify wall-clock contribution by component.

## Primary question

How much of current exact SWAP-trial wall-clock is attributable to producing the fresh accepted-direction / response tangent required by the live MODFLOW relinearization path?

## Frozen method

For each of the 12 P0 live groups:

1. run the exact live MODFLOW6 coupling on the production-shaped c=0.65 path;
2. record the exact sequence of MODFLOW-generated prescribed heads;
3. from a separately recreated but identical dynamic SWAP origin, replay exactly those heads with normal fresh accepted-direction production;
4. from another separately recreated identical origin, replay exactly those heads with accepted-direction production suppressed only in the copied research participant seam;
5. discard every replay candidate so no replay path changes accepted state.

The live run remains the authority for the actual coupled trajectory.

The two replay arms are only a wall-clock decomposition experiment.

## Arms

### FULL

Normal exact SWAP trial:

- same forcing;
- same c=0.65 temporal budget policy;
- same BALTOL02 authority;
- same physical solver;
- fresh accepted-direction requested;
- response tangent produced.

### QONLY

Identical exact SWAP trial except:

- accepted-direction calculation is suppressed in the copied research participant after the normal refresh decision;
- no tangent is required from the replay result.

No production source is modified.

## Required identity checks

For every replayed head:

- q_swap FULL versus QONLY must agree to floating-point physical identity;
- completed/accepted status must agree;
- temporal retry/substep counts must agree;
- nonlinear iteration counts must agree;
- mass completeness must agree.

If suppressing direction changes the physical solve path, P1 is invalid and must stop.

## Measurements

Per group and replay arm:

- total SWAP trial wall-clock;
- ns per exact trial;
- transaction calls;
- accepted substeps;
- attempts;
- retries;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- headcalc calls;
- backtracking attempts.

Compute:

`R_dir = T_FULL / T_QONLY`

and directional marginal fraction:

`F_dir = (T_FULL - T_QONLY) / T_FULL`.

Report both per group and aggregate paired totals.

## Interpretation

P1 provides a measured upper/lower bound for accepted-direction/tangent cost on the exact live head population.

It does not itself authorize removing the tangent from production. MODFLOW currently requires response information.

If directional work is a major fraction of exact trial time, the next optimization workunit should target a cheaper mathematically valid response derivative.

If directional work is minor, LIVE01 must continue into the base Richards/nonlinear path.

## Advancement

A directional-cost successor is justified if the paired aggregate experiment shows at least 20% of exact-trial wall-clock attributable to accepted-direction work.

Otherwise continue decomposition of the q/state solve.

No optimization or source change is admitted by P1.
