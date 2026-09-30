# F-PE-ELASTIC59 — bottom-mode-7 typed mass publication result

Date: 2026-09-30

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic59-mode7-typed-mass`

Qualified postimage:
`1f73eccc1fba4e3668d008e44a7e8dd88d9a7af4`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36690464263`

Job:
`109806190212`

Conclusion:
SUCCESS.

## Purpose

Close the Reference-binding contract gap identified by ELASTIC58.

Before ELASTIC59, accepted bottom-mode-7 free-drainage solves did not publish
the typed mass diagnostics already available for bottom modes 2 and 5.

ELASTIC59 adds that publication only.

## Production change

Exactly one production source file changed:

`src/adapter/mod_reference_richards_legacy_binding.f90`.

For accepted bottom-mode-7 solves, the binding now publishes:

- `unrounded_mass_balance_residual = sum(final compartment residual vector)`;
- `native_balance_rate_residual_available = .true.`;
- `native_balance_rate_residual_cm_per_day`;
- `integrated_mass_balance_residual_available = .true.`;
- `integrated_mass_balance_residual_cm = dt * native residual`.

No solver equation, HeadCalc calculation, constitutive relation, Jacobian,
retry rule, temporal policy, boundary semantics or mass tolerance changed.

## Qualification matrix

Twelve converged mode-7 cases were exercised:

- h0 = -75 and -20 cm;
- signed top-flux perturbation factors = -0.01, 0, +0.01 around free-drainage
  equilibrium;
- dt = 0.01 and 0.001 day.

A separate deliberately difficult retry probe verified fail-closed behavior.

## Exact typed-residual identity

For every converged case:

`native_balance_rate_residual_cm_per_day`

was bit-identical to:

`sum(workspace%richards%residual(1:n))`.

The integrated typed residual was bit-identical to:

`dt * native_balance_rate_residual`.

Qualification:
- A2 exact residual identity: PASS;
- A3 exact integrated identity: PASS.

## Independent physical interval ledger

The qualification independently reconstructed:

- initial soil storage;
- final soil + ponding storage;
- published top flux;
- published solver-owned free-drainage bottom flux.

Across all 12 converged cases:

maximum absolute physical ledger residual:

`6.01e-15 cm`.

Maximum absolute typed integrated equation-balance residual:

`5.73e-15 cm`.

Both are well inside the frozen hard `1e-12 cm` mass gate.

A4 physical ledger: PASS.

## Bottom-flux ownership

The caller supplied a deliberate sentinel bottom-flux value.

For every accepted mode-7 solve:

- the published bottom flux differed from the caller sentinel;
- it matched `-K_N` evaluated at the accepted candidate state within
  floating-point roundoff.

Therefore ELASTIC59 does not accidentally convert free drainage into a
caller-prescribed qbot path.

A5 qbot ownership: PASS.

## Retry fail-closed behavior

A deliberately difficult mode-7 case was forced out of accepted convergence.

For that result:

- typed native residual availability remained false;
- typed integrated residual availability remained false.

No failed or retry-advised solve claims accepted mass publication.

A6 fail-closed behavior: PASS.

## Preservation

Existing production semantics were replayed through current transitive build
closure.

Mode 2:
- F-SI38 prescribed-qbot temporal/mass contract: PASS.

Mode 5:
- F-SI25 prescribed-head Reference indicator seam: PASS.

O0/O2 semantic identity:
PASS.

Production source scope:
exactly one existing Reference-binding file.

## Gates

- A1 mode-7 typed residual publication: PASS;
- A2 exact worker-residual identity: PASS;
- A3 integrated residual identity: PASS;
- A4 independent physical ledger: PASS;
- A5 solver-owned free-drainage qbot: PASS;
- A6 retry fail closed: PASS;
- A7 mode-2 preservation: PASS;
- A8 mode-5 preservation: PASS;
- A9 O0/O2 semantic identity: PASS;
- A10 exact production source scope: PASS.

## Decision

Classification:

`QUALIFIED_MODE7_TYPED_MASS_PUBLICATION_ADMISSION_CANDIDATE`.

This workunit admits only the missing typed mass-publication seam.

It does not admit:
- a mode-7 temporal head budget;
- the defect indicator into production;
- C-SAFE into production;
- any new temporal tolerance;
- ELAS defaults.

The next permitted action is canonical admission of this narrowly scoped
contract patch, followed by an unchanged replay of ELASTIC58 Reference-only
budget calibration.
