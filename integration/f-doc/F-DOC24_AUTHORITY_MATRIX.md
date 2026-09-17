# F-DOC24 Groundwater and lower-boundary authority matrix

Date: 2026-09-17

F-DOC24 adds a reviewer-facing technical reference for the admitted Groundwater Coupling v1 lower-boundary composition. This matrix controls the claim surface. It creates no new scientific authority, production semantics, tolerance or backend admission.

## Frozen denominator

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- F-DOC24 start canonical: `2a6eb532c922add0afbc15fdf7f3bee11ed8ea33`

## Authority chain

Groundwater Coupling v1 is capability-distributed. No single file is promoted to a master theory authority.

The bounded authority path used by F-DOC24 is:

```text
frozen coupling/interface contracts
        |
        v
F-GC27 restricted direct-groundwater end-to-end qualification
        |
        v
F-GC28 Groundwater Coupling v1 completion audit
        |
        v
Status-A acceptance and current traceability/preservation authority
```

F-GC27 is independently qualified through F-VQ97 and canonically admitted through F-CI87. F-GC28 is independently qualified through F-VQ98 and admitted through F-CI88. F-GC28 closes the historical Groundwater Coupling v1 denominator without changing production or reference source.

## Claim matrix

| Topic | Permitted claim | Primary frozen authority | Explicit nonclaim |
| --- | --- | --- | --- |
| Lower-boundary head | SWAP lower-boundary pressure head and coupling hydraulic head are distinct quantities. With a valid common datum, `H = z_bottom + psi` after cm-to-m conversion. | `src/runtime/mod_groundwater_coupling_contract.f90`, blob `fc598d14...` | Pressure head is not silently reinterpreted as hydraulic head. No datum-free conversion. |
| Flux sign and units | Native SWAP `qbot > 0` is into the SWAP soil profile. Public `q_swap > 0` is outward from SWAP. Conversion is `q_swap = -qbot * 0.01 / 86400` in m/s. | coupling contract blob `fc598d14...` | No universal raw-code sign convention across solver, coupling and accounting layers. |
| Action/reaction pair | The paired groundwater interface flux satisfies `q_groundwater = -q_swap`; the interface flux residual is `q_swap + q_groundwater`. | coupling contract blob `fc598d14...`; F-GC27/F-VQ97 | A component-local exchange is not a net loss from the combined SWAP-groundwater system. |
| Whole-window exchange | The accepted SWAP whole-window bottom outward exchange is converted to a mean interface flux over exactly the same coupling window before groundwater trial evaluation. | `src/runtime/mod_groundwater_predictor_corrector_window.f90`, blob `fa2a5a45...` | No arbitrary temporal interpolation or change of time support is inferred. |
| Restricted predictor-corrector | The admitted route performs one predictor and one corrector from the same accepted SWAP/groundwater origin. Predictor candidates are discarded. | F-GC27/F-VQ97/F-CI87; predictor-corrector blob `fa2a5a45...` | No general unlimited fixed-point iteration, asynchronous coupling or arbitrary schedule. |
| Head convergence | Interface residual is `h_swap - h_groundwater`; convergence is `abs(residual) <= head_tolerance_m` under a valid externally governed, provenance-qualified policy. | `src/runtime/mod_groundwater_coupling_policy.f90`, blob `5e6fa9db...`; F-GC22 as incorporated by F-GC28 | No universal numeric head tolerance. This policy does not own Richards nonlinear tolerances, temporal budgets, application accuracy or mass tolerance. |
| Candidate publication | Computed groundwater/SWAP candidates remain tentative until publication preflight and accepted transaction commit. Predictor candidates never become accepted state. | predictor-corrector blob `fa2a5a45...`; exchange-service blob `e99ae052...` | Completion of a trial is not publication. Rejected/nonconverged candidates cannot be treated as accepted coupling state. |
| Interface mass ledger | Corrector whole-window SWAP outward exchange is staged, prepared and only then committed. Abort/rejection leaves committed exchange unchanged. | `src/runtime/mod_groundwater_interface_mass_ledger.f90`, blob `a867e04b...` | No duplicate booking of the same interface transfer on the combined-system balance. Trial/prepared exchange is not committed history. |
| Atomic publication | After preflight, SWAP candidate publication, prepared groundwater publication and ledger publication form the admitted accepted-state sequence. The frozen implementation treats failure of prepared groundwater publication after SWAP commit as an invariant violation, not a recoverable scientific path. | predictor-corrector blob `fa2a5a45...`; preparable exchange-service contract `e99ae052...` | No claim that arbitrary external services are transaction-safe merely because they implement a nominal adapter API. |
| External groundwater gateway | A restricted structural external gateway boundary is admitted and participates in the F-GC27 end-to-end composition. | F-GC26, inherited by F-GC27/F-GC28 | No broad MODFLOW backend, no backend constitutive-science validation from the adapter alone. |
| Restart | Accepted-boundary restart/split-run/replay for the admitted groundwater composition is part of the closed v1 denominator. In-flight trial/prepared publication state is deliberately not treated as committed restart state. | F-GC24, incorporated by F-GC28; mass-ledger restart contract | No general serialization of active external transactions. |
| MultiSWAP | The closed v1 denominator includes the qualified direct-groundwater MultiSWAP composition, deterministic aggregation, transaction isolation and coupling-window diagnostics. | F-GC20/F-GC25, incorporated by F-GC27/F-GC28 | No concurrent real-physics MultiSWAP coupling or parallel speedup claim. |
| Current preservation | Current Status-A traceability records same-tree targeted groundwater preservation, mixed-smoke coverage and accepted-state publication/rollback preservation. It labels that umbrella preservation attribution as F-GC29. | `docs/status-a/TRACEABILITY.md` | F-DOC24 does not equate that umbrella preservation attribution with the separate `integration/f-gc/F-GC29_*` response-sensitivity workunit and does not use the latter as the original Groundwater Coupling v1 scientific admission authority. |

## Exact frozen implementation anchors

The main source postimage used by F-DOC24 is the scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`.

Relevant immutable blobs are:

- `src/runtime/mod_groundwater_coupling_contract.f90` -> `fc598d14eabafcb025bb55621f7b00d6d1816f10`
- `src/runtime/mod_groundwater_predictor_corrector_window.f90` -> `fa2a5a45d558fbaaea242438915cdb7420b6503c`
- `src/runtime/mod_groundwater_exchange_service_contract.f90` -> `e99ae052fccd9992b76c12a91422a987dce059e2`
- `src/runtime/mod_groundwater_interface_mass_ledger.f90` -> `a867e04b088f61f686f693d07e470c3e9c33bdec`
- `src/runtime/mod_groundwater_coupling_policy.f90` -> `5e6fa9db6ddf60d3fc70ed4cec9a33858b0f9976`
- `src/runtime/mod_groundwater_swap_forcing_adapter.f90` -> `f3bf2effebc772b1e3417232d2baabe49ebb8da0`

F-GC27 additionally records the admitted external gateway, tile aggregation, accuracy binding, coupling response, restart and MultiSWAP blobs that compose the restricted end-to-end capability.

## Publication rules

1. Always name the sign convention together with the quantity. `qbot`, `q_swap` and normalized accounting amounts are not interchangeable raw variables.
2. Always name the head datum when converting SWAP pressure head to hydraulic head.
3. Treat the predictor as tentative. Only the accepted corrector path can become published coupled state.
4. Keep head convergence and mass conservation separate. Head convergence uses a governed tolerance; paired interface flux and the committed ledger use the admitted exact action/reaction accounting contract.
5. Do not cite the structural gateway as proof of a concrete backend's groundwater physics.
6. Do not turn the bounded one-predictor/one-corrector route into a generic iterative coupling claim.
7. Do not infer concurrent real-physics MultiSWAP coupling from the admitted deterministic MultiSWAP v1 composition.
8. No F-DOC24 page may change production source, reference source, scientific tolerances, coupling schedule or admission scope.
