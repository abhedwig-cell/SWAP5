# F-PE-ELASTIC58 — independent physical temporal-budget qualification result

Date: 2026-09-30

Status: QUALIFIED_PARTIAL_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-independent-head-budget`

Qualified postimage:
`d3eb81c77219c0d2f1423a407335bcafe309b803`

Canonical baseline:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Workflow run:
`36693527564`

Job:
`109815997988`

Conclusion:
SUCCESS.

## Question

Can the mode-7 conservative indicator plus C-SAFE enforce the independently
qualified TEMPORAL04/05 physical error envelope?

Frozen authority:
- head error <= 0.01 cm;
- theta error <= 1e-5;
- terminal bottom-flux relative error <= 1%;
- integrated bottom-exchange relative error <= 0.5%;
- hard mass remains separate.

Frozen ELASTIC54 scaling:
`alpha = 0.17320259355765216`.

Derived before execution:
`Binf_limit = 0.01 / alpha = 0.05773585599727987 cm`.

## Bank

Four ELASTIC55 profiles, four states, four perturbations, three ELAS regimes:

`4 * 4 * 4 * 3 = 192` controller sequences.

C-SAFE used up to 15 dt halvings and never assumed monotone Binf.

Results:
- accepted: `96`;
- exhausted safely: `96`;
- accepted with complete 32-substep Reference oracle: `42`;
- accepted with unavailable/incomplete 32-substep oracle: `54`.

O0/O2 C-SAFE decisions were identical.

## Physical result on oracle-qualified accepted points

All `42 / 42` complete-oracle acceptances pass every frozen physical gate.

Aggregate worst cases:
- max terminal |dh|: `4.5303820e-4 cm`;
- max terminal |dtheta|: `2.3198890e-6`;
- max terminal bottom-flux relative error: `0`;
- max integrated bottom-exchange relative error:
  `6.1280e-16`;
- independent mass-ledger failures: `0`.

Therefore:
- head failures: 0;
- theta failures: 0;
- terminal-flux failures: 0;
- exchange failures: 0;
- mass failures: 0.

This is a strong physical pass where the independent oracle exists.

## Oracle coverage blocker

The 32-substep oracle completed for only `42 / 96` accepted points.

The `54` unavailable oracle cases are strongly localized:

By state:
- h0 = -20 cm: `39`;
- h0 = -75 cm: `15`;
- h0 = +2 cm: `0`;
- h0 = +10 cm: `0`.

By ELAS regime:
- OFF: `18`;
- FIXED_1E6: `18`;
- GENERATED: `18`.

Thus oracle unavailability is exactly regime-independent in this bank and is
confined to unsaturated states.

By profile:
- 11060: `3`;
- 10260: `15`;
- 8016: `24`;
- 3030: `12`.

This does not implicate elastic storage. It implicates refined-oracle
solvability in the unsaturated/material domain.

## Interpretation

ELASTIC58 supports the composition:

`independent 0.01-cm head criterion`
-> `frozen global alpha`
-> `derived Binf threshold`
-> `C-SAFE`

for every accepted point where a complete independent 32-substep oracle can be
constructed.

The physical margins are large.

However, the evidence is incomplete because more than half of the accepted
points lack the required refined-oracle endpoint.

Those points are not counted as passes or failures.

## Decision

Classification:

`QUALIFIED_PHYSICAL_BUDGET_CANDIDATE_WITH_UNSATURATED_ORACLE_COVERAGE_BLOCKER`.

No production admission is authorized.

The next bounded workunit should attribute the 32-substep oracle failures in the
unsaturated states, preserving the same candidate controller and physical
budget.

The goal is oracle qualification coverage, not relaxation of the physical
error envelope.
