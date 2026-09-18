# PUB-GC manuscript figure and table plan

## Purpose

This plan maps each proposed publication visual to an already admitted evidence source or to the explicitly open E7 slot. It prevents figures from silently becoming new claims.

## Core figures

| ID | Figure | Primary message | Evidence | Status |
| --- | --- | --- | --- | --- |
| F1 | Coupling ownership and publication boundary | SWAP and MODFLOW keep solver/state ownership; trials and publication are separate | F-GC39–F-GC44, E2 | READY_FROM_EXISTING_EVIDENCE |
| F2 | Hydrological interface quantities | fixed plane, datum, `q_bot`, `q_u`, storage and accepted `V_u` are distinct | E1 + method contracts | READY_FROM_EXISTING_EVIDENCE |
| F3 | Numerical closure versus physical correction | strong iteration can greatly reduce interface residual while changing head negligibly | E3 + E3-R | READY_FROM_EXISTING_EVIDENCE |
| F4 | Finite-window response identity | `u_A≈u_FD`, B3 separates `|J_R|`, B5 loses symmetric `J_R` | E4 full derivative evidence | READY_FROM_EXISTING_EVIDENCE |
| F5 | Information value of response | Aitken/secant beat FP; oracle adds little over cold secant | E5 comparison | READY_FROM_EXISTING_EVIDENCE |
| F6 | Component-admission envelope | E6 stronger-response routes terminate at predictor/corrector capability boundaries | E6 active-drainage + 20-case state screen | READY_FROM_EXISTING_EVIDENCE |
| F7 | Realistic Hupsel result | standalone-selected control/high-dynamics days, loose versus strong | E7 | BLOCKED_M1_C3 |

F7 is not required to draw F1–F6. If E7 remains blocked at submission decision time, the manuscript must be framed as a bounded coupling-method/qualification paper rather than implying realistic validation.

## Recommended figure construction

### F1 — ownership and authority sequence

Panel A: component ownership. Panel B: one finite-window trial sequence. Panel C: publication boundary. Explicitly show `accepted -> trial -> discard/retain -> preflight -> MODFLOW finalize -> SWAP commit -> ledger commit`.

### F2 — physical interface schematic

Show the fixed SWAP lower plane, hydraulic datum, pressure/head transform, native `q_bot`, groundwater-facing `q_u`, profile storage and accepted integrated transfer. Use arrows only after fixing the public sign convention.

### F3 — E3 paired numerical/physical effect

Panel A: loose residual versus window/flux for valid cases. Panel B: loose-to-strong head correction. Use the same cases and make component-domain failures visible rather than dropping them.

### F4 — E4 response identity

Use B1–B5 as x categories or small multiples. Plot `u_A`, `u_FD`, `|J_R|` and `J_S` only where admitted. Mark B5 `J_R` unavailable rather than zero.

### F5 — E5 work comparison

Plot full-window SWAP evaluation count by `C` for FP, Aitken, cold secant, supplied `u_A` and zero-cost oracle. Preserve bounded-domain failures as symbols/annotations rather than extrapolating.

### F6 — E6 domain map

Panel A: active-drainage predictor succeeds but prescribed-head profile is `NOT_ADMITTED`. Panel B: 4×5 state/flux matrix colored by predictor readiness and largest symmetric valid head perturbation.

## Core tables

| ID | Table | Status |
| --- | --- | --- |
| T1 | Coupling quantities, units, sign, temporal support and authority | READY |
| T2 | E1–E7 experiment design and preregistered decision rules | READY except E7 outcome |
| T3 | E4 response identity values B1–B5 | READY |
| T4 | E5 oracle/secant information-value summary | READY |
| T5 | E6 negative stress-extension summary | READY |
| T6 | E7 realistic-day metrics and loose/strong results | BLOCKED_M1_C3 |

## Evidence files

- E4 machine-readable figure source: `docs/publication/evidence/PUB_GC_E4_FULL_RESULT.json` and `PUB_GC_E4_DERIVATIVES.csv`.
- E5 source: `PUB_GC_E5_INFORMATION_VALUE_RESULT.json` and `PUB_GC_E5_INFORMATION_VALUE_COMPARISON.csv`.
- E6 source: `PUB_GC_E6A_STATE_SCREEN_RESULT.json`, `PUB_GC_E6A_STATE_SCREEN_SUMMARY.csv`, and raw evidence under `docs/publication/evidence/`.
- E1–E3 figures should be generated only from the corresponding admitted result JSON files, not manually copied numeric notes.
