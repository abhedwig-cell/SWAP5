# A27 finite-contact result and bounded source-repair handoff

Status: SOURCE_REPAIR_QUALIFIED_FOR_REGIE_REVIEW; TWO_WAY_HISTORY_CONTRACT_BLOCKED.
Date: 2026-10-01 UTC.
Canonical reconciliation: 828df126e0c0d70f5cbfae51614bfc3b53e832a4.
Source-repair qualification postimage: 34a7861377da05727647d22937c25f8d73e702ef.
Column-run postimage: 76008ec089879708d01bd965b12d04cd3ed2ae61; research operator and column fixture are byte-identical at the qualification postimage. Subsequent oracle correction isolates Philip-only transfer; it does not change the operator.

## Bounded production repair

The actual composer/wrapper/real Reference Richards chain now conserves endpoint release into the matrix independently of cell thickness. The composer source is release/dt (areic cm/day), replacing release/(dz*dt). No solver ABI or physical parameter was changed.

| Cell thickness (cm) | Intended endpoint release (cm) | Measured paired matrix receipt (cm) |
| --- | --- | --- |
| 5 | 0.00089331194339199466 | 0.00089331194339181848 |
| 10 | 0.00089331194339199466 | 0.00089331194339070663 |
| 20 | 0.00089331194339199466 | 0.00089331194339015152 |

Maximum receipt mismatch is 1.844e-15 cm. The old 10 cm fixture measured only one tenth of the endpoint loss. This is a reproduced mass-ownership defect, not a disagreement with standard macropore theory. The existing declared-transfer ledger did not independently detect the missing matrix receipt.

Required local source, composer, live-preparer (zero-RFM and refinement), actual Richards binding, and serialized backend O0/O2 runtime/persistence gates pass on the persisted qualification postimage. Backend preservation initially failed because its compile list omitted the newly canonical qgwl provider; adding that dependency alone repairs the harness. No production lower-boundary code changed. The old failed log remains in the evidence archive.

## Finite-contact experiment

Contract: [finite-contact preregistration](PPA_WU05A27_FINITE_CONTACT_CONTRACT.md).
The existing hydrostatic/Philip-Darcy reduced contact law is integrated analytically over each vertical segment, restricted to its wetted intersection for unsaturated uptake. This introduces no tuned smoothing parameter. Saturated signed Darcy includes matrix seepage into the unfilled receiver. Explicit accepted-state budgets and paired matrix/receiver ownership are retained.

Boundary results, reproduced identically at O0/O2:

- Representative-point wetting jump: 0.08040716960416655 cm.
- Finite-segment first-contact change for a 1e-9 cm displacement: 8.04071762570856e-11 cm; analytic transfer tends to zero as wetted length tends to zero.
- Frozen-event-sorptivity saturation jump remains 0.05640716960416655 cm with finite geometry.
- Half-wet Philip-only and fully wet signed Darcy analytic oracles pass.
- Existing deterministic 20,000-request budget/replay screen remains green for the point-contact operator; it is not claimed as a 20,000-case finite-geometry screen.

Therefore finite geometry resolves this representative-point wetting falsifier only. It does not resolve the admitted frozen-event-sorptivity versus signed saturated Darcy transition.

## Evolving actual Richards columns

150 one-day cases, 1,500 sampled records: 2 hydraulic Ks values x 3 initial states x 5 exchange modes x 5 timesteps. New mode 4 is finite contact with current accepted-state node S, retaining previous modes 0-3. This is a mechanism ablation; standard mode 2 uses the production saturated-exchange primitive, not the full standard macropore runtime. No rainfall forcing is applied. Full fixture definitions remain in the contract, runner and Fortran source.

Maximum solver mass residual: 2.518e-15 cm. Maximum sampled joint matrix/receiver residual: 2.576e-14 cm. All solves completed; research fixture aborts on a failed solve and has no production retry or checkpoint coverage.

At dt=0.000125 day:

| Ks (cm/day) | Initial receiver (cm) | Standard signed primitive final receiver (cm) | Point/current-S final (cm) | Finite/current-S final (cm) | Finite last dt-halving change (cm) |
| --- | --- | --- | --- | --- | --- |
| 1 | 0 | 0.696999695 | 1.750108504 | 1.747022632 | -0.000183737 |
| 1 | 4 | 3.800220982 | 3.371122551 | 3.370105383 | -0.000345899 |
| 5 | 0 | 2.239661240 | 2.376558243 | 2.375414573 | +0.000002274 |
| 5 | 4 | 3.214558947 | 2.477472161 | 2.476334775 | -0.000028380 |

Dry profiles remain inactive in all modes. Refinement changes contract in magnitude in the listed wet fixtures; one slightly changes sign. Last-change contraction ratios are 0.497, 0.780, 0.116 and 0.423 respectively. This does not prove a universal convergence order, timestep-independent production stability, or full-runtime equivalence. Finite versus point geometry changes final storage modestly here; the much larger separation from the standard saturated primitive remains. Known model differences include current versus saturated conductivity and unsaturated sorptivity uptake. They are not resolved by per-case tuning.

[Receiver trajectories](evidence/PPA_WU05A27_FINITE_CONTACT_TRAJECTORIES.svg) show time-resolved exchange/storage behavior at the finest resolution. The evidence archive retains all sampled trajectory records, summary rows, CPU counters, nonlinear iterations and backtracking. Research CPU seconds are single realizations; no wall-clock speedup or scaling claim is made.

## Performance/equivalence frontier

| Route / regime | Evidence | Decision |
| --- | --- | --- |
| Old composer, active IC release | Actual matrix receipt loses a dz factor | Mass-ownership route falsified; source repair is required |
| Corrected existing one-way production split | Receipt, origin/replay and bounded A26 preservation gates pass | Bounded repair qualified for central regie review; not canonical admission |
| Wet matrix with finite macro receiver | Earlier filling/release ablations and present signed columns both show nonzero transfers | Omitting reverse exchange cannot support a practical replacement claim in these recharge regimes |
| Point-contact two-way research | Finite first-wetting and saturation-history jumps | Proposed transition route falsified |
| Finite geometry with event-frozen S | Wetting continuous; saturation jump persists | Geometry alone insufficient; two-way production integration blocked |
| Finite geometry with current S | 150-case matrix includes current-S mode; ledgers close and listed refinement changes shrink | Research candidate only; silently overwriting A26H history is not an eligible production fix |
| Zero-preferential control | Existing bounded live zero-RFM gate passes | E0 evidence only for that named gate; no full eight-regime envelope |

No E1 production envelope, multi-column throughput claim or faster/more-stable claim has been established. The full paired production A/B/C experiment remains OPEN. Mechanism differences are localized, but these ablations do not assign definitive E1/E2/E3 classes to unrun full production regimes. A speedup obtained by the mass-loss defect or omitted reverse route would not count as success.

## Concrete blocker and admission boundary

A26H makes event S persistent while an endpoint remains wet. With that retained positive S, switching to saturated signed Darcy produces a finite transfer discontinuity. Recomputing current S masks that incompatibility by changing the accepted history contract. A moving finite wetted wall additionally exposes previously unwetted segments whose contact age/seed is not represented by one endpoint-wide age and S. A physically justified transient uptake/history owner is required before a two-way production implementation can be qualified. No arbitrary blending, per-case tuning, or unsupported state defaults were introduced.

This is a demonstrated contract blocker for the tested proposed extension; it is not evidence that every mathematically possible two-way model fails. Two-way physics is materially relevant in the tested wet cases. The experiments do not establish that monolithic nonlinear coupling is necessary rather than a convergent transactional split.

Under integration/control/SWAP5_WORKSTREAM_REGISTRY.json, canonical admission belongs to central SWAP5 regie. The reviewable bounded repair is the composer conversion plus its independent actual-receipt harness; the backend compile-list dependency repair preserves the existing gate. Research files remain explicitly outside production dispatch. Regie can review that correction independently of the blocked new physics. No qualification/admission Action was launched and no canonical ref was changed.

Next substantive step: establish and preregister the transient wall uptake/history contract, including newly wetted contact, saturation, drying and reversal; then test it against these retained negative oracles before full paired rain-event benchmarks. The existing admitted production envelope must not be broadened on this evidence.

Evidence: [compressed complete records, logs and SHA256 manifest](evidence/PPA_WU05A27_FINITE_CONTACT_EVIDENCE.json.gz). Archive SHA256: a57ed20f3efc7cc5919da36afeef7a3d6a4cdff45d13ab3577ea8230fb72a360. Documentation source checks and strict MkDocs build passed locally; the generated site is outside the repository.
