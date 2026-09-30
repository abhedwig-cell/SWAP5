# F-PE-NLGLOB14Z42 result — larger-profile production-shaped trajectory timing

Date: 2026-09-30

Status:

`QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`

Qualification authority:

- workflow run: `36774835520`;
- job: `110090024530`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research postimage before result persistence:

`research/f-pe-nlglob14z42-large-profile-trajectory@f6e503a801ce91bfd66a89dfa9083d2a14a43574`

## Aggregate result

The N=64 production-shaped trajectory benchmark classifies:

`QUALIFIED_Z42_TRAJECTORY_TIMING_GAIN`.

The adaptive moving-interface manager is faster than the full 64-node reference trajectory while preserving the frozen physical gates.

## Frozen trajectory

- material: O05;
- full nodes: 64;
- initial tail: 49:64;
- initial active dimension: 49;
- dt: 0.00125 d;
- fixed top flux: -0.01 cm/d;
- qbot: 0;
- intervals: 4,000.

Both full and adaptive trajectories start from the same immutable origin and evolve independently.

## Physical result

All physical gates pass.

Observed maxima:

- max pressure-head difference: about `7.31e-205 cm`;
- max theta difference: `0`;
- max full per-interval ledger: about `7.42e-17 cm`;
- max adaptive per-interval ledger: about `7.42e-17 cm`;
- rollback/origin leak: `0`.

Final ownership:

- full final tail: 49:64;
- adaptive final tail: 49:64;
- full ownership events: 0;
- adaptive ownership events: 0.

Thus the benchmark is a stable reduced-regime trajectory with effectively exact full/adaptive physical agreement.

## Manager applicability

- reduced-route intervals: 4,000 / 4,000;
- reduced-route fraction: 100%;
- fallback count: 0;
- bypass count: 0;
- mean active dimension: 49;
- active-dimension histogram: n=49 for all 4,000 intervals;
- request-buffer reallocations: 1 during setup;
- full-candidate reallocations: 1 during setup;
- steady-state measured trajectory therefore uses persistent buffers.

## Work result

Cumulative deterministic work proxy:

- full work: 768,000;
- adaptive work: 588,000;
- adaptive/full work ratio: `0.765625`.

Equivalent deterministic work reduction:

about `23.44%`.

## Wall-clock result

Measured trajectory times:

- full trajectory: about `0.09657 s`;
- adaptive trajectory: about `0.08948 s`;
- adaptive/full wall-clock ratio: `0.92666`.

Equivalent trajectory wall-clock gain:

about `7.33%`.

The frozen Z42 timing-gain criterion requires ratio <0.95, and is therefore met.

## Interpretation

Z42 is the first evidence in this line that the reduced moving-interface mechanism produces a measurable trajectory-level wall-clock gain around the real compiled Heritage/reference solve-service.

The earlier sequence is now internally consistent:

- Z29/Z31R: reduced physics is viable;
- Z34/Z35: production-shaped manager seam and physical binding are sound;
- Z37/Z38: isolated microkernel overhead can dominate tiny solves;
- Z39: persistent manager overhead is negligible at real Richards solve-service scale;
- Z40/Z41: real reduced HeadCalc is physically equivalent and scales favorably with profile size;
- Z42: the solve-service gain survives sequential manager orchestration.

## Qualified claim boundary

Qualified:

- one N=64 production-shaped trajectory;
- independent full/adaptive evolution;
- physical-equivalence gates pass;
- 100% reduced-route usage;
- zero fallback/bypass;
- about 23.4% deterministic work reduction;
- about 7.3% measured trajectory wall-clock gain.

Not yet qualified:

- broader heterogeneous trajectory holdouts;
- BOFEK-wide portability;
- whole-SWAP end-to-end runtime gain;
- production numerical admission;
- production default change.

## Consequence

The moving-interface manager line has enough implementation and performance evidence to begin production-admission-candidate preparation.

The next workunit should remain small and must:

1. freeze a compact heterogeneous trajectory holdout set;
2. retain exact fallback/bypass behavior;
3. confirm no transaction/mass regression;
4. confirm wall-clock gain remains non-negative across holdouts;
5. package the manager route behind an explicit non-default production configuration;
6. prepare admission evidence without changing `LEGACY_NUMERICS` default.

## Production boundary

Research/qualification route only.

`LEGACY_NUMERICS` remains production default.
