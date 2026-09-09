# F-VZAA01 - Fail-closed VZAA donor separability and falsification plan

## Decision context

The direct published VZAA production path is already blocked by the SWAP5 conservation and lower-boundary gates. A standalone conservative VZAA derivative has also been deprioritized because LayeredMFP already occupies much of that architectural territory with stronger SWAP5-specific evidence.

The remaining scientifically interesting question is narrower:

> Does the VZAA history-aware transient flux relation contain a distinct, reproducible signal that improves an existing exactly conservative reduced-order route enough to justify its state and runtime burden?

This note defines the experiment required to answer that question before any VZAA-derived production code is considered.

## Source boundary

Primary source:

Sadeghi et al. (2026), Journal of Hydrology 673, 135467, DOI `10.1016/j.jhydrol.2026.135467`.

Source facts reconstructed from the paper:

- Eq. (3) expresses a layer-centred moisture flux as a sum of a history-dependent diffusive term and a conductivity/groundwater term.
- Eq. (5) evaluates the half-order moisture derivative `H` from the complete moisture history.
- Eq. (6) switches empirical `c` between `0.5` for `H <= 0` and `2` for `H > 0`.
- Eq. (7) relates the arithmetic mean of incoming and outgoing layer fluxes (`w=0.5`) to the analytical flux relation.
- Eq. (8) is the discrete layer water balance.
- Eq. (9) combines Eqs. (7) and (8) and is solved for the new layer water content before the outgoing flux is reconstructed.

The DOI-linked MATLAB supplementary code has not yet been directly captured. Therefore an implementation based only on these equations is an **independent reconstruction**, not a reproduction of the official algorithm.

## 1. Donor separability is not automatic

The VZAA transient term is structurally different from the current LayeredMFP homogeneous-face correction.

LayeredMFP currently evaluates a face closure from local hydraulic states and immutable shared hydraulic representation data. The accepted transient storage update remains exactly conservative in the experimental harness.

VZAA instead defines a **layer-centred** flux relation that depends on:

- current/candidate layer moisture;
- hydraulic diffusivity at that moisture;
- the complete temporal moisture history through `H`;
- previous-step water-table depth for `K_d`;
- the incoming layer flux and the simultaneous storage change through Eq. (9).

Consequently, copying the VZAA history term into a LayeredMFP face formula would be a new derivation, not a direct reuse of the published algorithm.

This creates a mandatory gate before any hybrid implementation:

`D0_DONOR_SEPARABILITY`

The gate asks whether a useful VZAA signal can be measured independently of the full VZAA state-update algorithm.

## 2. Why a warm-start argument is currently weak

The current F-LMFP07/F-LMFP08 experimental LayeredMFP transient path does not contain a global nonlinear Richards/Newton solve that needs a profile warm start. Its candidate trial computes face fluxes from the committed state and then performs an exactly conservative explicit storage update.

Therefore a VZAA profile predictor cannot currently justify itself by claiming to reduce LayeredMFP Newton iterations. There are no such iterations in this experimental path.

A VZAA donor must instead demonstrate at least one of the following:

1. better transient flux prediction at the same accepted conservative update structure;
2. a materially larger qualified hydraulic/process envelope;
3. a useful early-warning diagnostic for cases where the cheap closure will be inaccurate or rejected;
4. later, a measurable reduction in bounded correction work for groundwater/head coupling or another corrector that actually exists.

Until one of these is demonstrated, the history machinery is additional complexity without an identified production benefit.

## 3. Stage D0: diagnostic flux-signal experiment

The first experiment deliberately does **not** integrate a VZAA column and does not alter any accepted state.

For each layer and accepted time `t_n`, compute from the candidate model's own committed moisture history:

`H_i(t_n)` from published Eq. (5).

Then compute the two source-bound contributions from Eq. (3):

`q_hist,i = -sqrt(c_i * D_i(theta_i)) * H_i`

and

`q_steady,i = K_si * (K_i(theta_i) - K_d,i) / (K_si - K_d,i)`

so that

`q_vzaa_mid,i = q_hist,i + q_steady,i`.

For deep groundwater, where `K_d` is negligible, the second term approaches `K(theta)`.

### Important diagnostic convention

The history must come from the **candidate/LayeredMFP committed trajectory**, not from FullRichards. Using the reference trajectory to construct `H` would leak reference information into the candidate and would not test deployability.

The VZAA value remains diagnostic. It does not enter the water ledger.

## 4. Reference quantity

VZAA Eq. (7) describes a layer-midpoint flux using an arithmetic mean of incoming and outgoing flux for `w=0.5`.

For a compatible comparison, define for each layer:

`q_ref_mid,i = 0.5 * (q_ref_topface,i + q_ref_bottomface,i)`

from the FullRichards reference trajectory, and

`q_lmfp_mid,i = 0.5 * (q_lmfp_topface,i + q_lmfp_bottomface,i)`

from the exactly conservative LayeredMFP trajectory.

The first question is then not whether VZAA can replace LayeredMFP, but whether

`e_vzaa = q_vzaa_mid - q_ref_mid`

contains less or more error than

`e_lmfp = q_lmfp_mid - q_ref_mid`,

and whether the VZAA residual signal

`delta_q = q_vzaa_mid - q_lmfp_mid`

has a stable relationship with the actual LayeredMFP error

`e_needed = q_ref_mid - q_lmfp_mid`.

A useful donor should at minimum show stable direction and refinement behaviour in some clearly identifiable physical regime. A noisy or regime-reversing signal is not a safe basis for a bounded production correction.

## 5. Reuse of existing LayeredMFP evidence harness

The donor experiment should reuse the existing experimental structure rather than creating a separate reference framework.

Relevant live LayeredMFP evidence observed on branch `work/f-lmfp09-hydraulic-envelope-geometry`:

- F-LMFP08 qualified experimental representation: constrained continuous MFP Darcian ratio;
- final F-LMFP08 evidence run: `34271007976` at head `4ecc84210f6af4cbc4528b8b4a23b8c63093fbd8`;
- existing experimental code lives under `experiments/lmfp/`;
- `run_lmfp07_transient_abc.py` already defines conservative transient candidate trials, FullRichards comparisons, ordinary cases and five strong-gradient stress trajectories;
- `run_lmfp08_constrained_mfp_ratio.py` supplies the currently admitted experimental homogeneous-face correction.

The donor work should therefore extend or wrap that evidence shape in an isolated future cross-track branch. It should not copy the full LayeredMFP harness into F-VZAA01.

## 6. Required reference-capture extension

The current LayeredMFP A/B evidence is primarily oriented toward final-state, bottom-flux and transient aggregate metrics. The VZAA donor question requires **time-resolved face fluxes and layer moisture histories**.

Before D0 can run, the experimental FullRichards reference capture must expose, for each accepted output interval:

- time;
- layer/node moisture;
- layer/node head;
- all relevant face fluxes;
- top and bottom boundary fluxes;
- storage;
- exact mass-balance diagnostics.

This is reference-evidence output only. It must not change FullRichards physics or production output semantics.

The LayeredMFP candidate side must retain its accepted moisture history for the experiment only. That raw history is experimental diagnostic data, not a proposed persistent production state.

## 7. Case sequence

### D0-A: existing ordinary and stress trajectories

Start with the already established F-LMFP07/F-LMFP08 case family:

- six ordinary FullRichards A/B cases;
- three strong-gradient sand cases;
- strong-gradient clay downward case;
- strong-gradient clay upward case.

These cases are valuable because LayeredMFP error behaviour is already characterized and because no new groundwater physics must be invented just to ask whether the VZAA history term adds information.

### D0-B: direction reversal

Only if D0-A shows a coherent signal, add a surface-forcing trajectory that reverses between wetting and drying. This specifically probes the published switch between `c_w = 0.5` and `c_d = 2` and tests for discontinuity or hysteretic artefacts around `H = 0`.

### D0-C: shallow groundwater/capillary rise

Only after D0-A/B, introduce a qualified reference case with a shallow prescribed groundwater head. This is required before claiming value from the `K_d` contribution or bidirectional saturated-unsaturated exchange.

VZAA's own water-table update Eq. (10) is not used for this donor experiment because that storage operator already fails the current SWAP5 exact-interface qualification.

### D0-D: heterogeneous interface

Treat separately. The published VZAA analytical flux relation was derived for uniform soil and the paper reports degradation for an embedded clay layer. A donor signal may not be interpolated across heterogeneous interfaces unless separately qualified.

## 8. Time refinement and start-up

At least the existing coarse/fine refinements must be retained, and a third refinement should be added if practical.

The experiment must expose rather than hide the initial-time behaviour. The paper itself identifies a large start-up mismatch and notes that the history-dependent term is affected by initialization.

Report separately:

- first accepted step;
- early transient window;
- later trajectory.

A donor that appears useful only after discarding an unbounded spin-up period is not automatically suitable for generic coupling windows or cheap restart/recompute.

## 9. Metrics

No scientific tolerance is invented in advance. Characterization must report distributions and case-level evidence first.

Required metrics include:

- `q_vzaa_mid - q_ref_mid` by layer/time;
- `q_lmfp_mid - q_ref_mid` by layer/time;
- fraction and physical location where each candidate is closer to reference;
- sign agreement of `delta_q` with `e_needed`;
- magnitude ratio `delta_q / e_needed` where numerically meaningful;
- sensitivity to temporal refinement;
- behaviour around `H = 0` and the `c` switch;
- dry-tail and near-saturation behaviour;
- history length and history-evaluation count;
- bytes of raw experimental history per layer;
- additional arithmetic cost per layer/time step;
- any NaN, singular, clipping or hydraulic-domain failure.

Mass balance is still recorded, but D0 itself cannot improve or degrade it because the donor remains diagnostic and never modifies the accepted ledger.

## 10. Falsification rules

D0 is deliberately asymmetric: it is easier to reject the donor than to qualify it.

Reject the VZAA donor path for a physical regime if any of the following is robust under refinement:

- `q_vzaa_mid` is consistently less accurate than the current LayeredMFP midpoint flux;
- the residual signal has the wrong direction relative to `e_needed`;
- signal direction changes unpredictably with time-step refinement;
- the `H=0` switch creates a material discontinuity or unstable correction signal;
- useful behaviour requires reference-state history rather than candidate-state history;
- useful signal is confined to a regime already accurately covered by LayeredMFP and does not justify the additional history state/cost.

A mixed result is `NOT_QUALIFIED`, not a pass.

A promising D0 result only authorizes the next donor-representation experiment. It does not admit VZAA or a hybrid solver.

## 11. Stage D1: bounded donor representation, only if D0 survives

The literal full history is not production-admissible for MultiSWAP.

If D0 identifies a genuine signal, D1 must ask whether that signal can be represented with compact, bounded, transactional state. Candidate research directions include recursive or sum-of-exponentials approximations to the half-order history operator.

D1 must compare the compressed donor against the literal-history diagnostic, not only against FullRichards, so the numerical-method change is separately visible.

Required properties:

- fixed maximum persistent state per active layer/template;
- O(1) or otherwise explicitly bounded update work per layer per accepted step;
- checkpoint/trial/rollback without mutating committed history;
- restart sufficiency;
- generic nonuniform time intervals or an explicit fail-closed restriction;
- measured approximation error over the complete D0 case family.

## 12. Stage D2: conservative integration, only if D1 survives

Only after D0 and D1 may a donor influence a trial calculation.

The first integration should retain the existing exactly conservative accepted storage ledger. Suitable roles are limited to:

- a bounded flux-correction proposal subsequently limited/accepted by the conservative solver;
- a predictor for a bounded groundwater/head corrector;
- a fail-closed diagnostic that routes a column to a different execution class.

The donor may not silently become a new physical boundary condition, may not bypass conservation, and may not change active SWAP physics.

## 13. Value gate against LayeredMFP

Even if D0-D2 are technically successful, the donor is not justified unless it produces a measurable architectural benefit.

The comparison must answer one of these with evidence:

- Does it materially reduce error in a regime where LayeredMFP is otherwise outside its qualified envelope?
- Does it reduce bounded correction/retry work in a later coupling solve?
- Does it safely identify problem columns early enough to reduce batch tail latency?

If the answer is no, the correct outcome is to archive VZAA as scientific comparative evidence rather than carry its history machinery into SWAP5.

## 14. Current implementation decision

No donor code should be added to production or to the VZAA branch yet.

The next executable work, if continued, should be an **isolated cross-track evidence workunit** after the FullRichards trajectory-capture seam is identified. It may independently reconstruct Eqs. (3), (5) and the D0 diagnostic, clearly labelled as non-official reproduction until the supplementary MATLAB code is obtained.

Current decision:

`D0_DONOR_SEPARABILITY_SPECIFIED__EXECUTION_BLOCKED_ON_TIME_RESOLVED_REFERENCE_CAPTURE_AND_OFFICIAL_SUPPLEMENT_REMAINS_OPEN`
