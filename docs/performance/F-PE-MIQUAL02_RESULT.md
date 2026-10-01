# F-PE-MIQUAL02 result — reference-valid post-admission manager qualification

Date: 2026-10-01

Status:

`QUALIFIED_MIQUAL02_REFERENCE_VALID_MANAGER_BANK`

Qualification authority:

- workflow run: `36819635439`;
- job: `110232206442`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@0b231d1669cf38d069f14c6d2f0f07cd3bb1c5b1`

## Aggregate result

All five frozen reference-valid cases pass the physical, manager-route and performance gates.

Classification:

`QUALIFIED_MIQUAL02_REFERENCE_VALID_MANAGER_BANK`.

## Reference guard

All five full-reference preflights complete 4,000 intervals:

- B01_N64_T49;
- B12_N64_T49;
- O05_N64_T49;
- B12_N32_T25;
- O05_N32_T25.

No reference regression occurs.

## Adaptive physical and route result

All 5/5 adaptive trajectories complete.

Across every case:

- reduced route: 4,000 / 4,000 intervals;
- reduced fraction: 100%;
- fallback count: 0;
- bypass count: 0;
- accepted-origin leak: 0;
- physical ledger remains at approximately machine precision;
- theta difference is zero at reported precision;
- pressure-head difference remains effectively machine zero;
- final full/adaptive tail agrees;
- ordered ownership-event count agrees.

B12_N32_T25 includes four ownership events on both full and adaptive routes and still passes exactly.

## Performance result

Wall-clock ratios:

- B01_N64_T49: 0.92556;
- B12_N64_T49: 0.92680;
- O05_N64_T49: 0.92119;
- B12_N32_T25: 0.94781;
- O05_N32_T25: 0.94022.

All 5/5 are below 0.98.

Geometric-mean wall ratio:

`0.93226`.

Equivalent aggregate solver/trajectory wall-clock gain is about 6.8%.

Deterministic work ratios:

- N64 cases: 0.765625;
- B12_N32_T25: 0.78145;
- O05_N32_T25: 0.78125.

Geometric-mean deterministic work ratio:

`0.77188`.

Equivalent deterministic nonlinear-work reduction is about 22.8%.

## Interpretation

The post-admission evidence is stronger than the original four-case Z43E candidate bank in one important way: the five cases were selected only by independent full-reference solvability in MIQUAL01, before any MIQUAL02 adaptive result was exposed.

The manager therefore survives an additional reference-valid holdout layer across:

- three hydraulic archetypes;
- two grid sizes;
- both static-tail cases and one case with multiple ownership events.

The remaining limitation is not manager stability in this bank. It is the breadth of the full-reference-solvable application domain and forcing diversity.

## Qualified claim boundary

Qualified:

- 5/5 reference-valid post-admission cases;
- exact/near-exact physical trajectory agreement under frozen gates;
- 100% reduced-route use;
- zero fallback/bypass incidence;
- no state leak;
- about 22.8% deterministic work reduction;
- about 6.8% solver/trajectory wall-clock gain.

Not qualified:

- BOFEK-wide portability;
- O14 under the frozen MAXIT16 reference profile;
- dry-to-wet/infiltration/ponding forcing diversity;
- whole-SWAP wall-clock speedup;
- MultiSWAP throughput gain;
- production-default replacement.

## Consequence

The next meaningful successor is forcing/regime diversity on the reference-valid material/geometry domain.

Do not reopen local moving-interface reconstruction micro-tuning unless a new physical failure localizes there.

## Production boundary

No production default change.

The moving-interface manager remains an explicit opt-in canonical capability.

`LEGACY_NUMERICS` remains production default.
