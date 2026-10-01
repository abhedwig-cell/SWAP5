# F-PE-MIQUAL03 result — fixed-flux forcing diversity

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL03_FIXED_FLUX_FORCING_DIVERSITY`

Qualification authority:

- workflow run: `36820978966`;
- job: `110236273112`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

## Aggregate result

The frozen forcing-diversity bank qualifies.

Reference-valid cases: 21/25.

Reference-valid by forcing:

- DRYING: 4/5;
- NEUTRAL: 5/5;
- BASE: 5/5;
- INFILTRATION: 4/5;
- STRONG_INFILTRATION: 3/5.

All preregistered reference-coverage gates pass.

All 21 reference-valid adaptive trajectories pass the physical, route and performance gates.

Classification:

`QUALIFIED_MIQUAL03_FIXED_FLUX_FORCING_DIVERSITY`.

## Reference-invalid cases

Four cases are full-reference-invalid under the frozen MAXIT16 evidence profile:

- B12_N64_T49 / INFILTRATION: failure at interval 882;
- B12_N64_T49 / STRONG_INFILTRATION: failure at interval 1799;
- O05_N64_T49 / DRYING: failure at interval 2109;
- B12_N32_T25 / STRONG_INFILTRATION: failure at interval 738.

These are not manager failures.

Mass ledgers remain around machine precision before reference failure.

## Adaptive physical result

All 21 reference-valid adaptive cases complete 4,000 intervals.

Across the qualified adaptive set:

- reduced-route fraction: 100%;
- fallback count: 0;
- bypass count: 0;
- accepted-origin leak: 0;
- theta differences: zero at reported precision;
- pressure-head differences: effectively machine precision;
- hard physical ledgers remain near machine precision;
- final tail and event counts agree between full and adaptive routes.

The forcing bank includes actual moving-interface events.

Examples:

- B12_N64_T49 / DRYING: 9 ownership events on full and adaptive routes;
- B12_N32_T25 / DRYING: 5 events;
- B12_N32_T25 / BASE: 4 events;
- B12_N32_T25 / INFILTRATION: 8 events;
- O05_N32_T25 / DRYING: 1 event.

Thus the positive result is not limited to static saturated-tail cases.

## Performance result

Reference-valid cases below wall ratio 0.98:

21/21.

Geometric-mean wall ratio:

`0.93717`.

Equivalent aggregate solver/trajectory wall-clock gain is about 6.3%.

Geometric-mean deterministic work ratio:

`0.77659`.

Equivalent deterministic nonlinear-work reduction is about 22.3%.

Representative work ratios range from approximately 0.7656 for stable N64 cases to approximately 0.8125 for N32 drying cases with interface movement.

## Interpretation

The moving-interface manager remains physically and operationally stable across a materially broader explicit-flux forcing envelope than MIQUAL02.

The evidence now includes:

- drying;
- zero forcing;
- baseline infiltration;
- stronger infiltration;
- strong infiltration where the full reference itself remains solvable;
- multiple ownership transitions.

The dominant limitation exposed by MIQUAL03 is again full-reference solvability in selected B12/O05 forcing combinations, not reduced-manager instability.

## Qualified claim boundary

Qualified:

- 21 reference-valid fixed-flux cases;
- five forcing classes represented;
- manager correctness with static and moving interfaces;
- 100% reduced-route use;
- zero fallback/bypass;
- approximately 22.3% deterministic work reduction;
- approximately 6.3% solver/trajectory wall-clock gain.

Not qualified:

- dynamic atmospheric-top switching;
- runoff/ponding behavior;
- rainfall-demand competition;
- BOFEK-wide portability;
- whole-SWAP or MultiSWAP speedup;
- production-default replacement.

## Consequence

Proceed to a separate dynamic-top / runoff / ponding qualification workunit.

That successor must preserve reference-first gating and must not infer manager failure from a full-reference-invalid case.

## Production boundary

No production-default change.

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
