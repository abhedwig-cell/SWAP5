# PUB-GC notation, units and authority glossary

## Status

**FROZEN_JOURNAL_NEUTRAL_NOTATION — 2026-09-18**

This glossary controls notation across the manuscript, figures, tables and supplementary evidence. Journal formatting may alter typography, not scientific meaning.

| Symbol / term | Meaning | Unit / representation | Authority / caveat |
| --- | --- | --- | --- |
| `W=[t_n,t_{n+1}]` | one coupling window | time interval | communication/acceptance window, not an internal model timestep |
| `DeltaT` | coupling-window duration | day in native experiment design; seconds where public rate integration requires SI | each SWAP trial may contain multiple adaptive internal timesteps |
| `z_bottom` | fixed elevation of the SWAP lower coupling plane | m in public coupling contract | datum must be explicit |
| `psi_bottom` | SWAP pressure head at lower plane | native SWAP length basis; converted explicitly | not identical to a groundwater-table elevation |
| `H_interface` | hydraulic head at coupling plane | m | candidate during trial; accepted only after coupled publication |
| `H_ref` | predictor reference hydraulic head for one accepted origin/window | m | local reference for response linearization |
| `q_bot` | native SWAP lower-boundary hydraulic flux | commonly cm d⁻¹ in evidence | native sign is not silently equated with public exchange sign |
| `q_u` | groundwater-facing effective exchange rate | explicitly normalized public coupling basis | distinct from `q_bot`; trial quantity until coupled acceptance |
| `Q_u(t)` | time-dependent public exchange rate | public rate unit | integrated over the window to obtain authoritative transfer |
| `V_u` | accepted whole-window interface transfer | m water depth in publication evidence | authoritative only after ordered publication / ledger commit |
| `u_A` | accepted-trajectory response of prescribed-bottom-flux predictor map | normalized finite-window response coefficient | approximately `DeltaT (dH_end/dq_bot)^-1`; not a universal head-to-exchange Jacobian |
| `u_FD` | independent centred finite-difference estimate of the predictor response | same normalized response basis as `u_A` | used only where both prescribed-flux perturbations are valid |
| `J_S` | local derivative of SWAP storage change with prescribed head | normalized E4 derivative basis | defined only for an admitted symmetric head neighbourhood |
| `J_R` | local derivative of accepted-sign whole-window interface transfer with prescribed head | normalized E4 derivative basis | head-driven corrector response; unavailable where symmetric derivative is not admitted |
| `J_B` | derivative of non-bottom balance terms in differentiated mass closure | normalized E4 derivative basis | used to distinguish structural aliasing from general response identity |
| `q_SWAP` | SWAP-side public coupling rate at one candidate head | m s⁻¹ in E1/E3 evidence | candidate value until final publication |
| `q_GW` | groundwater-side coupling rate | m s⁻¹ in E1/E3 evidence | compared with `q_SWAP` for coupled residual |
| `r=q_SWAP-q_GW` | coupled flux residual | m s⁻¹ | algebraic convergence metric, not automatically a hydrological-error metric |
| `C` | controlled dimensionless coupling strength in E5 | dimensionless | mechanism variable for information-value experiment, not a field parameter |

## Public sign convention

The publication contract treats positive public exchange as transfer from SWAP toward groundwater. Native component signs are translated explicitly at adapters.

For the accepted E1 corrector:

```text
q_swap_public_m_per_s * DeltaT_s = ledger_exchange_m
```

within representation precision.

The originally preregistered opposite-sign hypothesis was falsified and remains recorded in the E1/E2 evidence trail.

## State-authority vocabulary

**Accepted origin** — immutable committed component state at the beginning of one coupling window.

**Trial / candidate** — alternative full-window trajectory evaluated from the accepted origin. It may contain physically meaningful state and flux but is not model history.

**Discard** — invalidate a candidate without changing committed component state or authoritative interface mass.

**Retained candidate** — converged candidate selected for publication, still non-authoritative before all publication preflights pass.

**Commit / publication** — ordered transition by which accepted component state and interface transfer become authoritative.

**Component-domain failure** — participant cannot return a valid candidate under the unchanged admitted numerical/physical profile. It is not called outer-coupling divergence.

**Coupling failure** — both participants continue to provide valid candidates but the outer coupling cannot satisfy its unchanged acceptance criterion.

## Typography rule

Repository source uses ASCII identifiers such as `DeltaT`, `q_bot`, `u_A` and `J_R` for traceability. A target journal may typeset these as ΔT, q₍bot₎, u_A and J_R provided the mapping remains one-to-one.
