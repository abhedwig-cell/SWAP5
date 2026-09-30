# F-PE-ELASTIC58A — refined-oracle solvability attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58a-oracle-solvability`

Qualified postimage:
`00bd630d018d2a5ca7e0ccbcb5041171e98c5941`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36684222490`

Job:
`109786244675`

Conclusion:
SUCCESS.

## Question

Why did all 97 C-SAFE accepted ELASTIC58 cases fail the preregistered
32-equal-substep direct Reference oracle?

## Exact replay

ELASTIC58A reproduced:
- the same four independent profiles;
- the same C-SAFE selector;
- the same frozen alpha and H_budget;
- exactly 97 accepted cases.

No physical/numerical policy changed.

## Primary attribution

Of the 97 failed 32-substep oracle chains:

- first-substep failures: `88`;
- late-chain failures: `9`;
- completed 32-substep oracles: `0`.

Thus approximately 90.7% fail immediately on the first refined substep.

All 97 failures have direct-solver status:

`2`.

The blocker is therefore overwhelmingly small-dt solver solvability rather than
accumulated 32-step trajectory drift.

## Per-profile attribution

### profile 11020
- accepted: 24;
- first-substep failures: 21;
- late-chain failures: 3;
- maximum failing substep: 3.

### profile 8120
- accepted: 25;
- first-substep failures: 25;
- late-chain failures: 0.

### profile 4015
- accepted: 24;
- first-substep failures: 18;
- late-chain failures: 6;
- maximum failing substep: 4.

### profile 3011
- accepted: 24;
- first-substep failures: 24;
- late-chain failures: 0.

The late-chain mechanism is therefore restricted to profiles 11020 and 4015 in
this bank.

## Single-step refinement discriminator

For each accepted initial state, the same direct solver was tested once at
fractions of the accepted dt.

Converged single-step counts across 97 cases:

- dt/2: `78`;
- dt/4: `60`;
- dt/8: `54`;
- dt/16: `42`;
- dt/32: `9`.

The dt/32 single-step convergence count is exactly the number of late-chain
oracle failures.

Interpretation:
- the 88 first-substep failures are already non-solvable at dt/32 from the
  original accepted initial state;
- the 9 late-chain cases do solve dt/32 from the original state, but become
  non-solvable after 1-3 successful refined substeps as state evolves.

## Relation to BALTOL02 authority

Canonical BALTOL02 already qualifies a Reference balance-rate floor:

`tol_effective = max(tol_configured, 2.8e-16 cm / dt)`

for both compartment and total balance convergence criteria.

Its purpose is specifically to recover very short-step Reference solvability
without changing:
- head tolerances;
- ponding tolerance;
- hard mass acceptance;
- temporal policy.

ELASTIC58's custom direct 32-substep oracle bypassed the serialized Reference
request boundary where this qualified effective tolerance is applied.

The direct oracle therefore used the immutable configured `1e-12` balance-rate
criterion at every substep rather than the BALTOL02 effective request value.

For representative ELASTIC58 refined dt values, BALTOL02 would increase only
the nonlinear balance convergence criterion while retaining the separate hard
mass gate.

This is a qualified existing mechanism, not a post-hoc new tolerance proposal.

## Hypotheses

H1, most failures occur on substep 1 due to the small-dt convergence window:
SUPPORTED, 88/97.

H2, the dominant blocker is oracle construction/solver solvability rather than
accumulated trajectory drift:
SUPPORTED.

H3, the pattern is largely regime-independent in the unsaturated states:
SUPPORTED by the cross-regime failure repetition observed in ELASTIC58 and the
uniform status-2 classification.

## Decision

Classification:

`QUALIFIED_SMALL_DT_REFINED_ORACLE_SOLVABILITY_BLOCKER`.

ELASTIC58's 0.01 cm physical budget remains unqualified, not physically
falsified.

The next bounded workunit should replay the exact same 97 accepted cases with
only the already-qualified BALTOL02 effective balance-rate floor applied inside
the direct refined-oracle substeps.

The candidate/full-step selector, alpha, H_budget, physical gates and hard
1e-12 mass-acceptance ledger must remain unchanged.
