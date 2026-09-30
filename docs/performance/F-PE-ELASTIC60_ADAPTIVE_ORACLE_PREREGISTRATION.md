# F-PE-ELASTIC60 — adaptive nested Reference-oracle qualification preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC59 — QUALIFIED_SMALL_SUBSTEP_ORACLE_SOLVABILITY_LIMIT`

Parent postimage:
`research/f-pe-elastic59-oracle-solvability@c4c815664779cb8549f7ab502d9d1b040317f830`

Canonical authority:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Question

Can the ELASTIC58 physical-budget qualification be recovered with an adaptive
nested Reference oracle that stops before the small-substep solvability limit?

## Frozen controller and physical envelope

Unchanged from ELASTIC58:

- `alpha = 0.17320259355765216`;
- head limit `0.01 cm`;
- theta limit `1e-5`;
- terminal bottom-flux relative limit `1%`;
- integrated bottom-exchange relative limit `0.5%`;
- derived C-SAFE threshold
  `Binf <= 0.05773585599727987 cm`.

No value is refit.

## Frozen accepted-point bank

Replay the exact four-profile ELASTIC58 controller bank:
- 11060;
- 10260;
- 8016;
- 3030;
- same states, perturbations, regimes, materialization and 15-level C-SAFE
  ladder.

The expected accepted/exhausted replay is `96 / 96`.

## Nested oracle levels

For every C-SAFE accepted point evaluate fixed-substep Reference oracles at:

`N = 2, 4, 8, 16, 32, 64`.

Each successful level records:
- terminal pressure-head vector;
- terminal water-content vector;
- terminal bottom flux;
- integrated bottom exchange;
- independent mass ledger.

## Adaptive triple selection

Candidate triples, from finest to coarsest:

- 16/32/64;
- 8/16/32;
- 4/8/16;
- 2/4/8.

A triple is eligible only if all three levels complete and pass the independent
mass gate.

For each physical metric define:

- `D1 = |O_N - O_2N|`;
- `D2 = |O_2N - O_4N|`.

For vector head/theta use max absolute component difference.
For terminal bottom flux and integrated exchange use absolute scalar difference.

The metric is contraction-qualified when:

`D2 <= 0.75 * D1 + floor`.

Frozen numerical floors:
- head: `1e-12 cm`;
- theta: `1e-14`;
- bottom flux: `1e-12 cm/day`;
- integrated exchange: `1e-14 cm`.

If more than one triple qualifies all four metrics, choose the finest one.

If no triple qualifies all four metrics, classify
`ADAPTIVE_ORACLE_UNAVAILABLE`.

No two-level fallback may count as physical qualification.

## Conservative oracle uncertainty

For a qualified triple, use the finest endpoint `O_4N`.

Bound the unresolved oracle tail for each metric by:

`tail <= 3 * D2`.

This corresponds to a geometric refinement tail whose subsequent contraction
does not exceed the preregistered 0.75 factor.

For the C-SAFE candidate C define:

- head bound:
  `max|h_C-h_O| + 3*D2_h`;
- theta bound:
  `max|theta_C-theta_O| + 3*D2_theta`;
- terminal-flux relative bound:
  `(|q_C-q_O| + 3*D2_q) / max(|q_O|,1e-12)`;
- integrated-exchange relative bound:
  `(|Q_C-Q_O| + 3*D2_Q) / max(|Q_O|,1e-12)`.

These are research bounds, not production tolerances.

## Hypotheses

H1. Adaptive triple selection materially improves independent-oracle coverage
over fixed N=32.

H2. Every adaptive-oracle-qualified C-SAFE acceptance satisfies the unchanged
TEMPORAL04/05 physical envelope under the conservative tail bound.

H3. Oracle qualification remains regime-independent in the unsaturated domain.

H4. Remaining unavailable cases are concentrated in profile/state combinations
where even N=8 cannot provide three nested successful levels.

## Gates

A1. C-SAFE accepted/exhausted replay is exactly `96 / 96`.

A2. Fixed N=32 completion remains exactly `42 / 96`.

A3. Adaptive triple selection is deterministic and uses only the frozen rules
above.

A4. Every selected oracle triple passes its three independent mass ledgers.

A5. Physical pass claims use the conservative candidate-plus-tail bounds, not
raw candidate-to-finest differences alone.

A6. No alpha, physical envelope, solver tolerance or C-SAFE criterion changes.

A7. O0/O2 C-SAFE decisions are identical.

A8. Zero production `src/**` changes.

## Decision

ELASTIC60 may qualify an adaptive independent Reference oracle for this research
line, or falsify the proposed contraction/tail construction.

It does not authorize production temporal-budget admission.
