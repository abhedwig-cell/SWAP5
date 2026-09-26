# F-PE-REPRO01 D8 — provider scratch singleton localization

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

D7 isolated the deterministic poison failure to the PROVIDER scratch family:

- ZERO: 40/40 PASS;
- DFDH: 40/40 PASS;
- RESIDUAL_DELTA: 40/40 PASS;
- SOURCE_SINK: 40/40 PASS;
- PROVIDER: 0/40 PASS;
- DCON_OLD: 40/40 PASS;
- FLUX_GRAD: 40/40 PASS;
- BAND: 40/40 PASS.

The PROVIDER family consists of:

- `provider_theta`;
- `provider_k`;
- `provider_capacity`;
- `provider_dkdh`;
- `provider_root_sink`.

## Question

Which individual provider scratch array can influence the exact mode-5 accepted-direction solve before authoritative overwrite?

## Protocol

Use the same D7 test-only backend and exact first-corrector request.

Before `solve_with_accepted_step_direction`:

1. ensure workspace shape;
2. reset the complete Reference workspace to zero;
3. poison exactly one provider scratch array with quiet NaN;
4. execute the unchanged production solve.

Arms:

- ZERO;
- THETA;
- K;
- CAPACITY;
- DKDH;
- ROOT_SINK.

Run 40 fresh processes per arm.

## Decision

Any singleton arm that reproduces the status-6 signature identifies a concrete provider scratch read-before-authoritative-write dependency.

If exactly one singleton fails, REPRO01 may proceed to source-level read/write tracing for that array.

If multiple singleton arms fail, trace each before selecting a repair.

No production source modification is admitted by D8.
