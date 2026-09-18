# PUB-GC manuscript table package

## Status

**T1–T5 BUILT FROM GOVERNED CONTRACTS / ADMITTED EVIDENCE**

Date: 2026-09-18.

This file is the evidence map for the journal-neutral manuscript tables. It does not introduce new calculations beyond simple counts and ratios already governed by the admitted publication evidence.

## T1 — typed coupling quantities

| Quantity | Hydrological role | Representation in this manuscript | Temporal support | Authority rule |
| --- | --- | --- | --- | --- |
| `H_interface` | hydraulic head at the fixed SWAP lower coupling plane | public coupling head in metres after explicit datum/unit transformation | candidate or accepted end-of-window head | trial heads are not committed state |
| `q_bot` | native SWAP hydraulic flux across the fixed lower boundary | native SWAP flux; publication experiments commonly report cm d⁻¹ | prescribed/evaluated within one finite window | a computed trial flux is not authoritative mass |
| `q_u` | groundwater-facing effective exchange | sign/unit normalized exchange supplied to groundwater; distinct from `q_bot` | finite-window rate/response quantity | trial value remains tentative until coupled acceptance |
| `u_A` | accepted-trajectory response of the prescribed-flux predictor map | `u_A ≈ ΔT (dH_end/dq_bot)^−1` after the contract's explicit unit normalization | local to one accepted origin and one window | optional response information; not authoritative transfer and not a universal `J_R` |
| `J_R` | derivative of accepted-sign whole-window interface transfer with prescribed head | `dV_u/dH` where a symmetric local head response is admitted | local to one accepted origin/window and boundary-value map | unavailable when a symmetric prescribed-head neighbourhood is not admitted |
| `V_u` | accepted integrated interface water transfer | whole-window transfer after sign/unit normalization | complete coupling window | authoritative only after successful ordered publication / ledger commit |

Source authority: coupling contracts F-GC30/F-GC39–F-GC44, E1/E2, and E4.

## T2 — publication experiment sequence

| Evidence block | Question | Frozen comparison / intervention | Preregistered guard | Current outcome |
| --- | --- | --- | --- | --- |
| E1/E2 | interface identity, state authority and exactly-once mass | real SWAP + live MODFLOW6 in the restricted F-GC44 envelope | representation-scale identities; rejected/preflight-aborted trials must leave authority unchanged | `SUPPORTED_RESTRICTED` |
| E3/E3-D/E3-R | when does iterative coupling change the solution? | window, predictor flux and groundwater response; loose versus iterative from identical origins | failed component trial is not called coupling divergence; tolerances unchanged | strict closure improves, head correction remains tiny; component envelope limits stronger cases |
| E4 | what response map is exposed by SWAP? | compare `u_A`, independent `u_FD`, `J_S`, `J_R` | centred perturbations only; no extrapolation through failed side | `u_A` is flux-driven predictor response, not universal `J_R` |
| E5 | how much is supplied response information worth? | FP, Aitken, cold secant, supplied `u_A`, zero-cost `J_R` oracle | separate ACCELERATE continuation only for reproducible ≥2-evaluation or convergence-domain advantage | modest derivative value; standalone ACCELERATE gate failed |
| E6 | can a stronger valid synthetic hydrological feedback regime be constructed? | active drainage route plus 20-case state/flux screen | no production tolerance/retry/physics relaxation; deterministic E6-B candidate rule | `CLOSED_NEGATIVE_WITH_BOUNDARIES`; no E6-B candidate |
| E7 | does the contract transfer to an authoritative realistic application? | frozen Hupsel dates 2003-06-17 and 2003-05-20; loose versus strong | standalone-only selection completed before coupled output; no post-hoc date/window/tolerance rescue | `STANDALONE_SELECTION_FROZEN / COUPLED_EXECUTION_PENDING` |

## T3 — E4 response identity

| Case | Window (d) | `q_bot` (cm d⁻¹) | `u_A` | `u_FD` | `J_S` | `J_R` | `|J_R|/u_A` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| B1 | 1e−4 | 1e−6 | 3.40294e−5 | 3.40295e−5 | 3.40283e−5 | −3.40283e−5 | 0.999970 |
| B2 | 1e−3 | 1e−6 | 2.68611e−4 | 2.68607e−4 | 2.68610e−4 | −2.68610e−4 | 0.999996 |
| B3 | 1e−3 | 1e−4 | 2.66574e−4 | 2.66574e−4 | 2.88218e−4 | −2.88218e−4 | 1.081190 |
| B4 | 1e−2 | 1e−6 | 1.19027e−3 | 1.19028e−3 | 1.19027e−3 | −1.19027e−3 | 1.000000 |
| B5 | 1e−2 | 1e−4 | 1.12016e−3 | 1.12016e−3 | unavailable | unavailable | unavailable |

Source: `PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json`. B5's missing head derivative is an admission/domain result, not a zero derivative.

## T4 — E5 information-value summary

| Comparison | Evidence | Result |
| --- | --- | --- |
| comparable cold-secant / zero-cost-oracle cases | B1, B2 and B4 across six `C` values | 18 |
| oracle saves exactly one full-window SWAP evaluation | comparable cases | 16 / 18 |
| oracle saves two evaluations | B2, `C=2` | 1 / 18 |
| oracle saves zero evaluations | B4, `C=1.5` | 1 / 18 |
| oracle extends convergence domain over cold secant | all comparable cases | 0 |
| supplied `u_A` versus oracle work count | all 18 comparable converged cases | identical |
| B3 mechanism case | all six `C` values | common first prescribed-head trial outside admitted SWAP response domain |

Source: `PUB_GC_E5_INFORMATION_VALUE_RESULT.json`. The oracle derivative acquisition cost is deliberately zero in this upper-bound information-value test.

## T5 — E6 stress-extension disposition

| Route | Valid evidence before stop | Limiting condition | Coupled continuation |
| --- | --- | --- | --- |
| active drainage | predictor `q_bot=0.002 cm d⁻¹`, `u_A=5.76044e−4`, complete mass accounting, residual `1.74e−16` | prescribed-head reference corrector returns `KERNEL_STATUS_NOT_ADMITTED` before any transaction call | live-MODFLOW matrix skipped by preregistered stop rule |
| accepted-state / flux screen | 20 cases; 8 predictor-ready; wetter low-flux states increase `u_A` | 12 cases at `q_bot≥1e−2 cm d⁻¹` fail the unchanged predictor transaction; symmetric corrector pairs: 4 at ±1e−6 m, 1 at ±1e−5 m, 0 at ±1e−4 m, 0 at ±1e−3 m | deterministic E6-B candidate count = 0 |

Source: `PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.json` and `PUB_GC_E6A_STATE_SCREEN_RESULT.json`.

## Open T6

T6 is reserved for the E7 loose-versus-strong coupled results. The standalone selection portion is now frozen in `PUB_GC_E7_STANDALONE_SELECTION_RESULT.json`; the M1-C3 prerequisite has passed. T6 remains open only until the coupled execution for the two frozen dates completes.
