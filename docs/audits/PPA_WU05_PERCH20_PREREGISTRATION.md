# PPA-WU05-PERCH20 preregistration — reduction numerical continuation persistence

Date: 2026-10-01

Status: `PREREGISTERED / RESTART_CONTINUATION`

Baseline:
`research/ppa-wu05-perch19-frreduq-retry-ladder@7de6d7cec0d1904e956387aaef62ae4690f76a92`

Current canonical reconciliation:
`integration/f-ci-canonical@42bb867e1da993fe2127d23fe3e449e5244f7407`

## Purpose

Persist the source-faithful PERCH19 numerical continuation:

- reduction level / `IDecMpRat`;
- stable-step counter / `NStep`;
- previous timestep / `dtold`;

without adding fields to the seven-field physical macropore continuation state.

## Architecture

Use the existing FMR template axis:

`numerical_continuation_layout_id`.

Add one explicit layout identity for macropore reduction continuation and one typed,
serialization-neutral restart payload.

The numerical continuation is committed-boundary metadata. It is not physical state and
must not be exposed as solver scratch.

## Gates

### G1 — layout identity and validation

The new layout is explicit, known and incompatible with templates that do not opt in.

### G2 — commit-only publication

A successful accepted PERCH19 trial may publish its candidate reduction continuation.

A rejected/discarded trial may not alter the accepted continuation.

### G3 — restart round trip

Export and restore must preserve exactly:

- level;
- stable_steps;
- previous_dt.

The restored next interval must begin at the restored reduction factor.

### G4 — recovery across restart

The ten-stable-step and larger-dt recovery semantics must survive a restart boundary.

### G5 — A18/PERCH19 active authority

The source-backed Andelst perched authority must still:

- start at factor 1.0 from a fresh continuation;
- retry automatically to 0.1;
- converge with the qualified active perched exchange and mass closure.

A restart from the accepted reduced state must start directly from factor 0.1 rather than
silently resetting to 1.0.

### G6 — preservation

Templates with `FMR_NUMERICAL_CONTINUATION_NONE` and the existing Richards temporal
history layout retain their current restart semantics.

A8-A10 default macropore execution remains unchanged.

## Hard constraints

- no fields added to `macropore_continuation_state_t`;
- no rejected-trial mutation of committed continuation;
- no restart inference from hydraulic state;
- no silent default to level 0 when a template declares the PERCH20 layout but payload is
  absent;
- no canonical admission from the historical research ancestry.

## Decision

A successful PERCH20 result may become the final research prerequisite for reconstructing
a production-admission branch from then-current canonical.
