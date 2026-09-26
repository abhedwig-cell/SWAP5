# F-PE-BALTOL01 P2 result — recovered fixed-substep oracle

Date: 2026-09-26

Status: `ORACLE_RECOVERED_WITH_ONE_TERMINAL_FLUX_MONOTONICITY_EXCEPTION`

## Protocol

The TEMPORAL03 independent certificate-free oracle was rerun with the P1 candidate:

`tol_rate = max(1e-12 cm/day, 2.8e-16 cm / dt_sub)`.

Thirty-two difficult dynamic-history corrector points were integrated with N=8, 16 and 32 equal fixed substeps.

## Result

All 32/32 points complete at all three refinement levels.

Mass accounting remains effectively exact:

- N=32 maximum per-step mass residual is at or below approximately 8.5e-21 cm on the reported matrix;
- aggregate residuals are zero or roundoff-scale.

31/32 points satisfy the preregistered monotonicity gate simultaneously for terminal head, water content, terminal flux and integrated bottom exchange.

Typical state convergence approximately halves from 8→16 to 16→32.

## Single exception

B01 wet, history +0.1, offset -0.01 cm:

- terminal state convergence is monotone;
- water-content convergence is monotone;
- integrated bottom-exchange convergence is monotone;
- terminal-flux difference is not monotone:
  - |flux8-flux16| ≈ 6.10e-7 cm/day;
  - |flux16-flux32| ≈ 5.37e-5 cm/day.

The 8→16 terminal-flux difference is anomalously tiny relative to the state/exchange refinement and therefore cannot establish that N=32 has failed to converge. It also cannot be ignored under the preregistered gate.

## Interpretation

The integrated-depth balance floor removes the TEMPORAL03 oracle blocker without sacrificing mass authority.

The oracle is not yet fully admitted because one terminal-flux metric needs one additional refinement level.

## Decision

Advance to P2R for the single B01-wet history +0.1 / offset -0.01 cm point using N=16, 32 and 64.

No production source change is authorized.