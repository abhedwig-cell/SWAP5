# F-PE-TEMPORAL04 P0 — oracle-qualified dynamic temporal-policy screen

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Candidate derivation

The existing Reference temporal indicator forms the raw temporal defect as:

`e_raw = 0.5 * dt * (h_dot_current - h_dot_previous)`.

Dynamic TEMPORAL03 origins showed that `h_dot_previous` strongly controls the certificate scale. P0 therefore tests history-aware budgets derived from that exact origin quantity, without fitting to oracle endpoint errors.

Let:

`Hprev = ||h_dot_previous||_inf`

and `dt` be the requested corrector-window duration.

Candidate arms:

- CURRENT_FIXED: `1e-5 cm`;
- HIST_HALF: `max(1e-5 cm, 0.5 * dt * Hprev)`;
- HIST_ONE: `max(1e-5 cm, 1.0 * dt * Hprev)`;
- FIXED_0P2: `0.2 cm`, used only as a high-completion benchmark, not as a preferred policy.

These formulas are frozen before oracle comparison.

## Matrix

Use the six difficult dynamic-origin families:

- B01 wet and mid;
- B12 wet;
- O05 wet;
- O14 wet and mid;

with both +/-10% physical history directions and signed corrector offsets:

- +/-0.001 cm;
- +/-0.01 cm.

Total: 48 physical corrector points per policy arm.

## Reference oracle

Use the independently recovered fixed-substep Reference oracle with the admitted BALTOL02 balance floor:

`tol_rate = max(configured_tol, 2.8e-16 cm / dt_sub)`.

Use N=32 as the standard refined oracle. Use N=64 for any point whose existing refinement evidence requires it.

## Measurements

For each candidate policy and physical point record:

- computed temporal budget;
- completion status;
- transaction attempts and retries;
- temporal and solver rejection counts;
- runtime;
- terminal max |dh| versus oracle;
- terminal max |dtheta| versus oracle;
- terminal bottom-flux difference;
- integrated bottom-exchange difference;
- mass residual.

## P0 interpretation

P0 is comparative and does not admit a temporal policy.

A history-aware candidate is promising only if it materially improves completion/retry behavior over CURRENT_FIXED while retaining oracle errors of the same order as the full-step exact Reference candidate.

FIXED_0P2 is a completion benchmark only and must not be selected merely because it passes more cases.

## Stop conditions

Stop or split if:

- a history-aware formula produces nonfinite or negative budgets;
- oracle availability is lost;
- mass accounting is incomplete;
- improved completion requires materially larger oracle error.

No production temporal-policy source change is allowed.