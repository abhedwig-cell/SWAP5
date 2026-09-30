# F-PE-ELASTIC58 — physical temporal head-budget qualification result

Date: 2026-09-30

Status: QUALIFICATION_BLOCKED_BY_REFINED_ORACLE_SOLVABILITY

Branch:
`research/f-pe-elastic58-physical-budget`

Qualified workflow postimage:
`df0fca00ed1c3db87fdab81efd97f51a05742804`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36682975596`

Job:
`109782364862`

Conclusion:
SUCCESS as a qualification harness.

## Question

Can the explicit research budget

`H_budget = 0.01 cm`

combined with frozen

`alpha = 0.17320259355765216`

and the C-SAFE refinement pattern preserve the complete independent physical
TEMPORAL04/05 envelope on new mode-7 profiles?

## Source-feasibility amendment

The first run stopped before physical execution because the frozen BRO artifact
contained no second eligible independent one-horizon profile after excluding
the ELASTIC55 profile.

Before any physical result existed, the preregistered selection was amended to
preserve four independent profiles and at least three distinct horizon-count
classes without requiring an exhausted class.

The amended deterministic selection produced:

- 11020;
- 8120;
- 4015;
- 3011.

No numerical result participated in selection.

## Controller result

Across the four independent profiles:

- total state/forcing/regime sequences: 192;
- C-SAFE accepted: 97;
- C-SAFE EXHAUSTED: 95.

The selected dt was always the first full-converged, indicator-available point
satisfying:

`alpha * Binf <= 0.01 cm`.

No alpha or H_budget refit occurred.

## Refined-oracle result

Every one of the 97 C-SAFE accepted cases failed to complete the preregistered
32-equal-substep direct Reference oracle.

Aggregate:

- accepted: 97;
- oracle incomplete: 97;
- physically comparable accepted/oracle pairs: 0.

Therefore none of the preregistered physical comparison gates could be
evaluated:

- terminal |dh|;
- terminal |dtheta|;
- terminal qbot error;
- integrated bottom-exchange error;
- independent candidate/oracle mass comparison.

The zero values printed for aggregate maxima are placeholders caused by the
absence of any completed oracle pair and are not physical evidence.

## Interpretation

This result does **not** establish that H_budget=0.01 cm violates the physical
error envelope.

It establishes that the chosen independent qualification authority was
unavailable over the entire accepted set.

The harness intentionally failed closed when the refined oracle was unavailable,
so it emitted:

`F_PE_ELASTIC58_PHYSICAL_BUDGET=FALSIFIED`.

That marker means the budget was not qualified under the preregistered
acceptance contract. It must not be interpreted as a demonstrated physical
error-envelope exceedance.

The actual classification is:

`BUDGET_NOT_QUALIFIED_ORACLE_UNAVAILABLE`.

## Profile-level oracle availability

- profile 11020: 24 accepted, 24 oracle-incomplete;
- profile 8120: 25 accepted, 25 oracle-incomplete;
- profile 4015: 24 accepted, 24 oracle-incomplete;
- profile 3011: 24 accepted, 24 oracle-incomplete.

The failure is therefore systematic rather than profile-local.

## Decision

Classification:

`QUALIFICATION_BLOCKED_BY_REFINED_ORACLE_SOLVABILITY`.

No physical temporal budget is admitted.

The next bounded workunit must attribute the refined-oracle failure before any
budget claim is revisited.

Required attribution:
- failing oracle substep index;
- solver status and work at failure;
- whether failure occurs on the first refined substep or after accepted
  progression;
- whether failure is caused by the known small-dt convergence window;
- whether an independently qualified alternative oracle construction exists
  without weakening solver/mass policy.

No H_budget, alpha, controller or physical gate may change inside that
attribution workunit.
