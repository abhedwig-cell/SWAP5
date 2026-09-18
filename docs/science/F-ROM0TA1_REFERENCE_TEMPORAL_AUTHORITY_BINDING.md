# F-ROM0TA1 — Reference-Richards temporal-authority binding

## Scope

F-ROM0TA1 is a ROM-0 qualification workunit. It does not build a ROM and does not change production/reference physics, solver controls, retry policy, RossFast, groundwater coupling, or the existing R2 experiment.

The question is whether the canonically admitted Reference-Richards model temporal certificate can support a defensible accepted transient full-order authority for ROM research.

## Reconcile

The ROM branch head before this workunit is `d5b5bc3b7d6513a0647ccfdad5f80e9e01b927df`. Current canonical was reconciled at `79bc0b03398d762112542791c967646a8dc2c37a`. The live delta since the ROM branch merge-base is publication-only and does not change the temporal-indicator, FMR runtime, transaction, Reference solver, or ROM test surfaces used here.

## Existing authority

### F-SI38 indicator semantics

`mod_reference_richards_temporal_indicator` requires a converged Reference-Richards candidate and an accepted predecessor right derivative. For a step of duration `dt` it forms

`d_n = (h_candidate - h_base) / dt`

and the raw local time defect

`e_raw = 0.5 * dt * (d_n - d_{n-1})`.

It then applies the admitted restricted Reference-Richards defect operator. For prescribed qbot, bottom mode 2 is Neumann and contributes no state-dependent bottom-face stiffness. The operator solve produces `delta`. The implementation reports

`raw_m_norm = ||e_raw||_M`

`defect_m_norm = ||delta||_M`

`bounded_m_norm = min(raw_m_norm, 2*defect_m_norm)`

and

`B_inf = bounded_m_norm / sqrt(min_i(C_i * dz_i))`.

Therefore the native indicator is a pressure-head-scale quantity in cm. F-SI38 independently reconstructs the operator and proves implementation identity for its admitted fixture envelope. F-SI38 explicitly does **not** establish a universal or application-specific head budget and does not establish that `B_inf` is a rigorous upper bound on full-versus-refined Reference error for B01/B14.

### Persistent derivative/history lifecycle

`FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY` selects a committed-state layout containing `fkt_temporal_indicator_history_t`. The history payload is numerical continuation state, not physical storage state. It is cloned with candidate/checkpoint state. The temporal service reads the predecessor derivative from the candidate state, evaluates the indicator, and writes the current derivative into that candidate state. Rejected candidates are discarded with their updated history. Accepted candidates become committed state, so only accepted-step derivative history advances.

FMR44R additionally proves that the initial committed history can be seeded explicitly. Its qualification fixture seeds the predecessor derivative to zero for a stationary predecessor.

### Model-certificate transaction semantics

The canonical numerical config carries an optional model-owned scalar budget. For Reference Richards, FMR interprets that scalar as a positive finite head budget in cm and normalizes

`C_h = B_inf / H_budget`.

The generic model-certificate transaction accepts temporal accuracy only when the certificate is available, finite, nonnegative, and `C_h <= 1`. Otherwise it rolls back to the checkpoint and applies the ordinary transaction retry scaling. Mass acceptance remains an independent gate.

FMR44R/F-VQ75/F-CI62(P) qualify this wiring for a prescribed-qbot runtime fixture. Their `2.5e-11 cm` budget is explicitly qualification-only evidence and is not reusable as a ROM, production, coupling, or application accuracy threshold.

## Authority gap addressed by F-ROM0TA1

The existing chain proves how the indicator is computed, transported, normalized, committed and consumed. It does not answer the ROM-specific empirical question:

> For B01 and B14 near the proven R1 gravity-steady seed, how does `B_inf` relate to the actual Reference full-step versus two-half-step endpoint difference under the frozen 1% transient perturbation?

Until that relation is measured, no ROM head-error budget is selected and model-certificate acceptance is not used as trajectory authority.

## Measurement principle

F-ROM0TA1 first measures the certificate without using a head budget. Direct Reference solves are used only as a diagnostic measurement surface, not as final trajectory authority. Each row compares one principal full step against two half steps from the exact same R1 seed and forcing. The production F-SI38 indicator is evaluated on the principal full step and on both refined half steps with the predecessor derivative lifecycle reproduced explicitly.

The experiment records head, water-content, storage, flux, mass and solver-work differences. It classifies whether `B_inf` is empirically conservative or underestimating relative to the observed full-versus-refined head difference, but it does not promote that finite matrix to a mathematical bound.

Only after this measurement may a separate workunit bind an independently justified scientific/application head-error budget and test the actual model-certificate transaction as ROM trajectory authority.
