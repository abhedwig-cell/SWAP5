# Unified surface-control-volume probe preregistration

Date: 2026-10-03
Status: OPT_IN_PROVIDER_IMPLEMENTED__TRANSACTION_TEMPORAL_GATE_UNQUALIFIED

## Question

Can an explicit local surface store, solved together with the Richards top flux and a signed external-head exchange, remove the imposed-head route gate from the stage recession case while preserving exactly-once water accounting?

## Test-only constitutive/coupling law

The initial prototype was test-only. It has now been implemented behind the explicit `FMR_TOP_SURFACE_FORMULATION_UNIFIED_CV` selector in `src/adapter/mod_b110_unified_surface_cv_provider.f90` and the serialized FMR backend. The default imposed-head formulation remains unchanged. SWAP owns local surface storage `S(Hs)` and the soil column; the external owner supplies stage `Hr` and owns the external reservoir. The surface balance for each trial is

`S(Hs)-S0 = dt * (Qexternal - Qsoil)`,

with zero atmospheric forcing in this fixture, `Qsoil = Kface*((Hs-h_top)/d+1)` (positive into soil). Use `G=Kface/d`, so external and soil interface conductances use the same face scale, not a calibrated resistance. The first prototype used `G*(Hr-Hs)` without a sill. That law was rejected: while external stage was dry it continued drawing water from the external owner. The executed variant respects the existing 0.01 cm sill continuously:

`Qexternal = G * (max(Hr-sill,0) - max(Hs-sill,0))`.

This permits signed exchange when either owner has water above the sill and gives zero exchange when both are below it. It is continuous but has a derivative kink at the sill; that kink remains a numerical design question. The surface-head Jacobian uses the active one-sided derivative.

Local storage integrates `max(Hs-elevation,0)` over a uniform subgrid relief distribution on `[-D,D]`: zero below `Hs=-D`, `(Hs+D)^2/(4D)` for `-D < Hs < D`, and `Hs` above `D`. Thus `D` is the half-range about the SWAP datum. This is a different geometry from the existing TOP03 `[0,D]` microrelief contact probe and its `H^2/(2D)` storage law; their amplitudes are not interchangeable. The monotone scalar surface equation is solved to roundoff inside each dynamic-top evaluation. The derivative `dHs/dh_top` is returned from the implicit equation using the step-frozen face conductivity. The tested `D=0.05 cm` and conductance scale 1 are not selected field parameters.

## Fixed driver and gates

Use the production MvG provider (including the selected near-saturation width), actual `HeadCalc`, `SWBOTB=7`, `SWKIMPL=0`, the existing geometry-2 dry profile and 0.25-day rise/plateau/recession shape. Run both the original 0.02 cm peak (same TOP03 forcing) and a 2 cm peak above the 0.01 cm sill so reverse exchange is exercised. Test widths 0.2 and 2 cm at refinements 1..4096, O0/O2. No changes to solver tolerances, bottom physics, or mass thresholds. At every accepted solve require the existing soil balance gate; independently record local surface closure `ΔS-dt*(Qexternal-Qsoil)`, combined soil/surface/external/bottom closure, Qexternal sign through recession, and refinement completion. Reject any non-finite or unbracketed surface solve.

The refinement matrix is direct-solver diagnostic evidence. The provider also has a narrow FMR invocation test, but the external conductance and microrelief scale remain uncalibrated.

## Results

Local runs on 2026-10-03 completed all refinements 1, 2, ..., 4096 for widths 0.2 cm and 2 cm under both stage amplitudes. Each run completed in both `-O0` and `-O2`; numeric output matched exactly after removing CPU timing.

On the original TOP03 0.02 cm peak, both widths completed 4096 steps in 12288 Newton iterations. Maximum accepted-step soil balance residual was `1.34e-15 cm`, combined ledger residual was `3.19e-14 cm`, maximum SCV closure was `6.67e-16 cm`, and integrated external transfer versus materialized ledger differed by `2.73e-14 cm`. There were 2047 positive external-flux steps and zero negative-flux steps: with this small hydrograph local surface head did not persist above the 0.01 cm sill during stage recession, so the external connector shut off and the local surface store drained into soil. The fine-refinement trajectory completed, but this small-stage fixture does not exercise outward exchange.

For comparison, the existing imposed-head provider on this same original stage profile failed at 4096 after 2116 accepted steps for both widths; at 0.2 cm it completed refinements 1024 and 2048 with 2303 and 4475 total Newton iterations before failing at 4096. The SCV case completes at 4096 but uses 12288 iterations. The prior no-ponding-gate counterfactual is a distinct test implementation and also failed at 1024 and 2048, then completed 4096 in 8806 iterations (2 cm width). Thus the SCV result improves completion robustness at a clear work cost; it does not show a monotonic cost advantage.

For the 2 cm peak, 4096-step iteration totals were 9429 (0.2 cm) and 9389 (2 cm). The maximum accepted-step soil balance residual was `1.00e-15 cm`; the combined soil/surface/external/bottom ledger residual was `6.66e-16 cm` (0.2 cm) and `1.11e-15 cm` (2 cm). Maximum SCV closure was `1.13e-14 cm` for both widths.

At the 2 cm peak and 4096 steps the sill-aware external flux was inward on 2055 steps and outward on 1673 steps for both widths. Signed cumulative external supply was 1.37215 cm (0.2 cm) and 1.37306 cm (2 cm); the materialized SWAP-to-external transfer was its negative to within `2.61e-13 cm` and `2.34e-13 cm`, respectively. This demonstrates bidirectional, exactly-once balance in this direct fixture. The full-run storage changes were 0.31397 cm and 0.31393 cm, with bottom transfers -1.05818 cm and -1.05913 cm.

### FMR transaction integration probe

The opt-in provider is bound by `mod_fmr_serialized_reference_backend` when forcing explicitly selects `FMR_TOP_SURFACE_FORMULATION_UNIFIED_CV`. The backend uses its existing accepted top-exchange materializer and attempt-scoped exchange window. Admission restricts this experiment to reference B1.10, BASE state, `SWBOTB=7`, `SWKMEAN=1`, `SWKIMPL=0`, and no evaporation, snowmelt or runoff. The original imposed-head selector remains the default.

`bash tests/fapp/run_fapp09_ribasim_external_surface_water_profile.sh unified-cv` passes O0/O2 and produces `FAPP09_UNIFIED_SURFACE_CV_TEMPORAL_BLOCKER=PASS`. At the 0.03125-day interval the Richards solve executes and converges in 6 iterations with finite `qtop=-0.0240249711 cm/day`, but the FMR interval remains incomplete with zero accepted substeps and three temporal rejections, even with temporal tolerance `1e15`. The rejected transaction publishes no top-exchange carrier. The branch's default imposed-head case is also rejected at the temporal gate, so the current evidence points to a separate acceptance blocker after the local nonlinear solve. No accepted SCV transaction, full/half composition, replay, restart or publication behavior is qualified.

The source cause is recorded in `TOP03_JOINT_NEARSATURATION_SURFACE_DECISION.md`: `fmr_serialized_temporal_identity` returns zero only for bitwise-identical ordinary B1.10 endpoint states and `huge()` for any difference, independent of the finite temporal tolerance. Disabling full/half checking is rejected by execution admission. The callback also receives only full/half endpoint states; the external surface transfer remains in attempt scratch, so the current comparator cannot establish convergence of the coupling exchange even if a state norm were substituted. The separate canonical temporal-indicator route rejects dynamic top boundaries. This falsifies the claim that the surface CV alone resolves the TOP03/Ribasim production blocker.

`bash tests/fapp/run_fapp09_ribasim_external_surface_water_profile.sh preservation` passes O0/O2, including `FAPP09_TOP03_DEFAULT_OFF_PRESERVATION=PASS`. Thus the explicit selector leaves the legacy/default-off path unchanged in the tested configuration.

### Qualification limits / next tests

- One geometry/profile, one forcing shape, and one topological exchange law were tested. The 2 cm stage peak is an additional recession stress case; the original 0.02 cm peak was also run unchanged.
- Existing TOP03 research separately supports partial microrelief contact at fixed shallow stages, falsifies uniform microrelief alone for partial-to-full stage evolution, and supports finite contact resistance in a bounded stationary local law while identifying missing layer storage in dry-start transients. This SCV probe has not yet been compared against that matched contact-layer formulation; its conductance/storage law is a separate prototype.
- The local surface store reuses the solver candidate ponding state; no separate transactional state object or Ribasim ledger was added.
- FMR rejected-trial nonpublication is observed, but accepted-trial rollback/replay/restart, publication-after-accept, external owner feedback, runoff, rainfall, evaporation, groundwater exfiltration, and multi-step coupled timestep negotiation are not qualified.
- The linear conductance `G=Kface/d` and 0.05 cm microrelief depth are experiment parameters, not calibrated or selected physics. The sill law is continuous but not differentiable at activation.
- A new explicitly selected provider path exists in production source, but it is unadmitted and remains an experiment. No accepted surface-water contract changed, and this is not a production-admission candidate.
- The direct solver route is promising for the local nonlinear boundary failure, but it does not satisfy the current FMR temporal acceptance contract. The next investigation must carry branch-selected integrated external exchange alongside soil state in full-versus-composed-half temporal comparison and qualify application-scaled error budgets; merely raising a scalar temporal tolerance cannot address the current exact-identity callback.
