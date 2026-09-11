# F-PM07B Restricted Soil-Temperature Process Candidate

## Authority pin

This is a post-RB1 owner work unit. It does not modify or reopen the Restricted Production Baseline v1.

- F-PM07 readiness closeout: `94154805f08c20473545ed1eb25539cd91ecc08f`
- F-PM07 decision: `QUALIFIED_SOIL_TEMPERATURE_MIGRATION_READINESS`
- current canonical authority observed at work-unit start: `integration/f-ci-canonical@0aeb0a2ed4096e1f9493d3dabc70962ea5270182` (`F-CI42P`)
- immutable RB1 final release authority: `release/f-rb02-restricted-production-baseline-v1-final-authority@b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`
- implementation base: exact immutable RB1 authority `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`

The RB1 authority is a descendant of the current F-CI42P canonical authority. Starting this post-RB1 candidate from RB1 preserves the released baseline as the exact ancestor while leaving RB1 itself immutable.

## Readiness-child scope consolidation

F-PM07 reserved a narrow child sequence in which F-PM07B covered state/transaction/restart and F-PM07C covered the numerical heat provider. The present post-RB1 instruction deliberately uses F-PM07B as the first bounded process-materialization candidate. This work unit therefore consolidates only the minimum pieces needed for one coherent restricted candidate: thermal data contract, numerical conduction provider, compact state, transaction/restart semantics, read-only temperature view, energy diagnostic for the supported formulation, and MultiSWAP isolation evidence.

This consolidation does **not** absorb the separately reserved frost or snow responsibilities. It does not claim the full F-PM07 production programme complete.

## Exact first restricted profile

The candidate supports only:

1. one-dimensional numerical soil heat conduction using the audited legacy De Vries sensible-heat capacity and conductivity formulation;
2. the legacy node/compartment placement and fully implicit tridiagonal discretisation;
3. an externally supplied prescribed soil-surface temperature for each generic interval `[t0,t1]`, corresponding to the source-bound `SWTOPBHEA=2` Dirichlet route without importing legacy table/file handling;
4. a zero-heat-flux lower boundary, corresponding to source-bound `SWBOTBHEA=1`;
5. interval-average volumetric water content supplied through a process-facing hydraulic view, with the reference-compatible average `0.5*(theta_start + theta_end)`;
6. a compact persistent numerical thermal state consisting only of the active-node temperature profile;
7. worker/job-owned tridiagonal and constitutive scratch;
8. trial materialisation from committed state without mutation, followed by explicit commit by the owning runtime/process boundary;
9. a read-only semantic temperature-field view for future crop, hydraulic-constitutive and other process consumers;
10. sensible-energy storage and boundary-flux residual diagnostics for this restricted no-source/no-phase-change formulation.

## Explicit exclusions

The candidate does not support or silently emulate:

- frost hydraulic restrictions, frozen conductivity or freeze-thaw phase change;
- snow insulation or snow-to-soil thermal boundary exchange;
- latent heat or ice-content state;
- the analytic annual-wave temperature provider;
- air-temperature top-boundary mode;
- prescribed top heat-flux or mixed surface heat-flux/temperature modes;
- prescribed bottom temperature;
- legacy `.swp`, `.tss`, `.tgs` parsing, interpolation cursors or file paths;
- direct HeadCalc, Newton, Jacobian or soil-water solver-workspace access;
- a broad surface-energy-balance redesign;
- canonical admission or production qualification.

Unsupported physical combinations must fail closed at the candidate interface or remain unreachable. No excluded physics may be silently disabled.

## Source-bound provenance

The audited legacy archive remains the F-PM07 pin:

- `SWAP_4.3.1(6).zip` SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- inner `SWAP.ZIP` SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- `SWAP/temperature.f90` SHA-256 `92c39d296f41a60cfe3b66f8d1886ea938a53b4e0ea49e7ae1a23dd9680bd338`

The hashes were rechecked before materialisation.

## Unit reconciliation

The legacy module-level declarations and the actual numerical equations use:

- temperature: degree C, with differences equivalent to K;
- volumetric sensible heat capacity: `J cm-3 K-1`;
- thermal conductivity inside the timestep equations: `J cm-1 K-1 day-1`;
- geometry: cm;
- time step: day.

A legacy DeVries routine header labels the returned heat capacity as `J/m3/K`, while the implementation explicitly multiplies by `1e-6` and the module declaration states `J/cm3/K`. The target treats this as a documentation-unit discrepancy, not as a physics change: the implemented `J cm-3 K-1` unit is retained and made explicit.

## State/data ownership

- `PARAMETER`: grid geometry, layer/material fractions, saturated water content, De Vries constants and selected restricted boundary policy.
- `PERSISTENT_STATE`: active-node temperature profile only.
- `FORCING`: prescribed surface temperature for the requested generic interval.
- `HYDRAULIC_VIEW`: start/end volumetric water content only; no solver internals.
- `RESULT`: trial end-temperature profile plus boundary and sensible-energy diagnostics.
- `SCRATCH`: old-temperature work copy, interval-average water content, heat capacity/conductivity, face conductivity and tridiagonal vectors.
- `LEGACY_IO_ONLY`: table arrays, input filenames, `afgen` interpolation cursors and parsing state.
- `OBSOLETE_FOR_THIS_PROFILE`: frost-derived arrays and snow-resistance terms.

## Qualification boundary

F-PM07B is an owner qualification only. The preferred terminal decision is:

`QUALIFIED_RESTRICTED_SOIL_TEMPERATURE_PROCESS_CANDIDATE_READY_FOR_INDEPENDENT_FVQ`

Any such decision still requires a separate F-VQ and then a separate F-CI admission before canonical use.