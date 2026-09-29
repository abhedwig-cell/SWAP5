# F-PE-ELASTIC08 — serialized runtime per-layer ELAS result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Canonical base:
`integration/f-ci-canonical@d71cdae32abac62bd76e78a1f8897fc9e879c1c6`

Current candidate head:
`work/f-pe-elastic08-runtime-materialization-clean@e7e78eb2d09f27015b5057721fefd7ea122ab314`

PR:
`#754`

## Production scope

Exactly one production source file changes:

`src/runtime/mod_fmr_serialized_reference_backend.f90`.

No new ELAS field is introduced.

The existing runtime-owned fields are reused:

- `elasticity_active`;
- node-local `cofgen(:,:)`;
- exact legacy row `cofgen(24,:)=ELAS(:)`.

The admitted ELASTIC05 provider is materialized with:

- `enable_elastic_storage = elasticity_active`;
- `specific_elastic_storage_input = cofgen(24,:)`.

No numerical value transformation occurs.

## Preparation qualification

Dedicated qualification run `36524858723` on head
`dfa43f256e9093ed50607e79b193ae439eab3a55` passed.

Across all 36 exact Staringreeks-2018 materials:

- elasticity OFF preparation identity: PASS;
- elasticity ON identity against direct ELASTIC05 preparation: PASS;
- heterogeneous node-local row-24 ownership: PASS;
- O0/O2 preparation identity: PASS.

## Fail-closed qualification

The runtime rejects before provider execution:

- negative ELAS;
- non-finite ELAS;
- ELAS + KSATEXM;
- ELAS + direct retention/AHL;
- ELAS + tabulated hydraulics;
- ELAS + hysteresis.

The NaN path was explicitly repaired so finite validation occurs before any
ordered comparison under `ffpe-trap=invalid`.

Result:
`F_PE_ELASTIC08_R4_FAIL_CLOSED=PASS`.

## Serialized dynamic identity

The preregistered eight-case R3 matrix passed at both O0 and O2:

- B01/WET
- B01/POND
- B12/WET
- B12/POND
- O05/WET
- O05/POND
- O14/WET
- O14/POND

For every case, runtime materialization from
`elasticity_active + cofgen(24,:)` is compared with direct, already-qualified
ELASTIC05 typed preparation through the same serialized FMR backend.

Required identities pass for:

- completion class;
- retries;
- nonlinear iterations;
- internal retries;
- linear solves;
- backtracking attempts;
- complete mass-ledger values;
- accepted pressure head;
- accepted water content;
- ponding;
- groundwater level.

Observed deterministic counters in this isolation fixture are identical for all
eight cases:
- nonlinear iterations: 3;
- backtracking attempts: 3;
- linear solves: 3;
- retries: 0.

This is transport/materialization identity evidence, not a performance claim.

Markers:
- `F_PE_ELASTIC08_R3_CASES=8`;
- `F_PE_ELASTIC08_R3_SEED_MATRIX=PASS`;
- `F_PE_ELASTIC08_RUNTIME_GATE=PASS`.

## Default-off preservation

The same qualification run replays the admitted FKT22 serialized runtime gate.

Both O0 and O2 pass:

- default-off trajectory preservation;
- accepted-route provenance;
- rejected-trial isolation;
- physical state identity;
- mass-accounting identity.

Markers include:
- `FKT22_FMR_RUNTIME_O0=PASS`;
- `FKT22_FMR_RUNTIME_O2=PASS`;
- `FKT22_FMR_RUNTIME_O0_O2_IDENTITY=PASS`;
- `FKT22_FMR_PRODUCTION_RUNTIME_GATE=PASS`.

## Source-boundary gate

`F_PE_ELASTIC08_SOURCE_SCOPE=PASS`.

The only production file in the current-canonical delta is the serialized
reference backend.

## Current-head equivalence

The successful eight-case qualification head is
`dfa43f256e9093ed50607e79b193ae439eab3a55`.

The current candidate head differs from that green head only in
`.github/workflows/f-pe-elastic08.yml`, adding workflow concurrency and
`cancel-in-progress` so superseded ELASTIC08 runs no longer accumulate.

No production source, test oracle, seed-matrix runner or preregistered acceptance
condition changed after the successful run.

Therefore the green numerical/runtime evidence applies unchanged to the current
candidate head.

## Scientific boundary

F-PE-ELASTIC08 transports a pre-existing soil/material parameter.

It does not:

- select an ELAS value;
- make `1e-6 cm^-1` a default;
- derive ELAS from MvG parameters;
- infer activation from nonzero row 24;
- introduce legacy input syntax;
- qualify ELAS + KSATEXM/AHL;
- alter timestep/convergence/transaction policy.

## Decision

F-PE-ELASTIC08 is a qualified bounded production admission candidate.

After admission, F-PE-ELASTIC09 may lift the separate production-application
bootstrap rejection for this already-qualified Reference/MvG envelope.
