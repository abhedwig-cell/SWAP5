# F-AHL47 — direct-retention provider current-postimage screen

Date: 2026-09-25

Status: `PREREGISTERED_PRODUCTION_SHAPED_SCREEN`

Parent evidence: F-AHL46 demonstrated a derivative-consistent direct-index Hermite theta/C representation that is materially faster than current analytical demand.

## Architecture

Research provider:

- full hydraulic `evaluate()` remains authoritative analytical;
- conductivity demand remains analytical;
- point conductivity remains analytical;
- only WATER_CONTENT and CAPACITY demands use the direct-index Hermite retention representation;
- theta and C come from the same cubic interpolant;
- 256 intervals per decade over |h|=1..1e6 cm;
- outside represented domain, demand falls back to analytical;
- representation is built outside timed solves.

This explicitly avoids reopening K approximation, qbot scope or SWKIMPL=1.

## Initial solver screen

Use current-postimage Reference Richards, prescribed-head bottom mode 5, homogeneous B01 fixture.

Require:

- same convergence status;
- identical nonlinear iteration count;
- identical backtracking count;
- max |dh| <= 0.05 cm;
- max |dtheta| <= 1e-4;
- mass residual <= 1e-12;
- paired timing, 7 alternating pairs.

No production admission from this screen.
