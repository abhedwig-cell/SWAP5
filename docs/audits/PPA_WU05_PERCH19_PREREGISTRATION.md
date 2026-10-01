# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `PREREGISTERED / PERCHED_NUMERICAL_CONTINUATION`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@77f47a7d98cece4b371fdf078525a7ade7daec4a`

Current canonical reconciliation:
`integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2`.

Namespace rule:

This workunit uses the collision-free `PPA-WU05-PERCH*` namespace. The historical
generic perched A11-A18 ancestry must not be merged wholesale into canonical because
canonical now owns overlapping generic PPA-WU05 identifiers for another workstream.

## Purpose

Migrate the exact B1.11 macropore exchange reduction controller required by the
source-backed A18 perched authority.

A18 established that:

- unreduced inner exchange `FrReduQ=1` requests retry;
- the exact next source level `FrReduQ=0.1` converges;
- hardcoding 0.1 would not be source-faithful production behavior.

## Exact source state machine

B1.11 defines:

`FrReduQ = 0.1 ** IDecMpRat`

with `IDecMpRat = 0..3`.

On nonlinear failure with macropores active and `IDecMpRat < 3`:

- increment `IDecMpRat`;
- set the reduction flag;
- record current `dt`;
- retry without committing the failed physical candidate.

On successful convergence while `IDecMpRat > 0`:

- increment stable-step counter `NStep` up to 10;
- if `dt > dtold` or `NStep >= 10`:
  - record current `dt`;
  - reset `NStep=0`;
  - decrement `IDecMpRat` by one.

Therefore the reduction level is numerical continuation across accepted timesteps, not a
physical macropore continuation field.

## Hard ownership rule

Do not add reduction state to the seven-field physical macropore continuation contract.

If persisted production continuation is required, use an explicit numerical-continuation
state/layout compatible with the existing FMR restart architecture.

Rejected trials must not mutate accepted physical or accepted numerical continuation.

## Gates

### G1 — exact state-machine oracle

Qualify a typed side-effect-free controller against the exact source transitions:

- factors `[1, 0.1, 0.01, 0.001]`;
- bounded failure escalation 0→1→2→3;
- no escalation beyond 3;
- successful recovery after ten stable accepted steps;
- successful recovery when timestep increases;
- deterministic replay from the same numerical checkpoint.

### G2 — A18 active perched retry

On the persisted source-backed A18 fixture:

- start at accepted reduction level 0;
- first inner solve at factor 1 must remain rejected/retry;
- second attempt at level 1 / factor 0.1 must converge;
- only the accepted factor-0.1 candidate may publish matrix/macropore state;
- level 1 becomes accepted numerical continuation.

### G3 — reject/replay

Discarding the accepted candidate before commit must leave both:

- seven-field accepted macropore physical state;
- accepted reduction numerical continuation

unchanged.

Replay from the same checkpoint must reproduce the same accepted factor and candidate.

### G4 — restart

Persist and restore the accepted reduction level/recovery counters through an explicit
registered numerical-continuation layout.

The next interval must start from the restored reduction level, not silently reset to 0.

### G5 — source recovery

Demonstrate source recovery semantics:

- ten stable accepted steps at unchanged dt reduce level by one; or
- a larger accepted dt reduces level by one according to the exact B1.11 condition.

### G6 — preservation

Default/non-inner A8-A10 behavior remains unchanged.

A16/A17 inner-callback semantics remain unchanged when reduction level is zero.

## Admission boundary

PERCH19 may qualify the numerical controller and research integration.

Any canonical production-admission branch must later be reconstructed from then-current
canonical with only the required perched code/evidence carried forward. Do not merge the
historical A11-A18 research ancestry wholesale.
