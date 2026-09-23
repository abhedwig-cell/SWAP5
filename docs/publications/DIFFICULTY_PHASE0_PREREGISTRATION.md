# DIFFICULTY Phase 0 — preregistered falsification experiment

**Status:** PREREGISTERED DESIGN, NO EXPERIMENTAL OUTCOMES INSPECTED  
**Authority base:** `integration/f-ci-canonical@187e30153c890151768e929170d14bb22af1d86d`  
**Purpose:** determine whether a standalone scientific claim about physically structured nonlinear difficulty in Richards-equation simulation survives falsification.

## 1. Scientific question

> To what extent does nonlinear difficulty in Richards-equation simulation have a transferable physical structure, and which pre-trial hydrological state transitions distinguish universally difficult from numerical-method-sensitive regimes?

This work does **not** preregister solver switching, ML accuracy, instrumentation, or SWAP5 architecture as novelty.

### H1 — physical information
Pre-trial hydrological state and forcing add out-of-sample information about subsequent numerical difficulty beyond timestep and numerical history.

### H2 — soil transfer
Important physical relationships retain direction and useful predictive information for hydraulic parameterisations withheld from derivation.

### H3 — cross-method structure
At least part of the physical difficulty structure remains recognisable across independent nonlinear numerical methods.

Interpretation rule: H1 alone is performance modelling; H1+H2 without H3 is method-specific numerical hydrology; H1+H2 plus partial H3 keeps the standalone DIFFICULTY hypothesis alive.

## 2. Experimental unit and immutability

The experimental unit is a **pre-trial hydrological transition**, not a complete SWAP run:

`Transition = {checkpoint_state, forcing_contract, boundary_state, dt, grid_contract}`.

The checkpoint MUST be captured before any tested solve. Every counterfactual method/dt branch MUST restore exactly that checkpoint. A branch MUST NOT mutate the checkpoint used by another branch.

Required execution semantics:

`restore(checkpoint_j) -> apply fixed forcing/dt/method -> trial -> record -> discard trial state`.

No counterfactual Phase-0 branch may commit its final state into another branch.

## 3. Method matrix

Primary cross-method comparison:
1. the canonical iterative Richards method available at experiment implementation time;
2. a second, genuinely distinct iterative nonlinear method already qualified or obtainable without changing production physics.

Modified Picard or L-scheme is acceptable for item 2. **No new solver is to be implemented solely to rescue this publication hypothesis.**

RossFast is a secondary alternative-formulation comparator where its admitted application envelope permits the same physical transition. RossFast MUST NOT be described as a third nonlinear iterative solver.

Before data generation, the implementation workunit MUST bind exact method names, versions, tolerances, admissibility envelopes and failure semantics to canonical evidence.

## 4. Preregistered physical regimes

R1 **Quasi-equilibrium drainage**: low-gradient control states, away from saturation and boundary switching.

R2 **Dry-soil infiltration**: low antecedent effective saturation under positive surface influx; systematically vary antecedent saturation and forcing relative to local conductivity.

R3 **Strong wetting-front propagation**: states with an established steep wetting front. Front strength is measured prospectively, not assigned from solver outcome.

R4 **Near-saturation / capillary-fringe interaction**: states approaching saturation and/or undergoing material capillary-fringe displacement; vary groundwater depth.

R5 **Strong drying / evaporative-front development**: relatively wet antecedent state under strong atmospheric demand.

R6 **Atmospheric boundary transition**: states spanning the physical neighbourhood before, near and after an admissible flux/head switching condition. Distance to the switching threshold is a predictor, not an outcome.

Regime membership rules and numerical thresholds MUST be frozen before outcome inspection. Thresholds may be calibrated from state distributions only if solver outcomes remain blinded.

## 5. Soil design

Phase 0 uses four contrasting hydraulic parameterisations. Three should represent realistic contrasting hydraulic behaviour; one may be a physically admissible stress parameterisation with strong constitutive nonlinearity.

The design MUST retain the actual hydraulic parameters, not only texture labels. At minimum, where applicable: residual/saturated water content, alpha, n, saturated conductivity and pore-connectivity parameter.

Phase 1, if admitted, should move from categorical soils to continuous hydraulic parameter space.

## 6. TrialDifficultyRecord v0

Each record is immutable after generation and contains provenance plus four separated namespaces.

### identity
- experiment_id
- preregistration_revision
- canonical_commit_sha
- checkpoint_id
- counterfactual_group_id
- soil_id
- regime_id
- method_id
- grid_id
- simulation_time
- trial_id

### phys — available before solve
Profile arrays or lossless references to them:
- pressure_head
- water_content
- effective_saturation
- hydraulic_conductivity
- moisture_capacity `dtheta/dh`
- `dK/dh` when canonical constitutive authority permits stable evaluation
- root-water sink state where active
- groundwater/head state relevant to the lower boundary

Derived prospective descriptors:
- min/max/median/Q10/Q90 of h, theta, Se, K and C
- max absolute vertical gradients of h, theta, Se and log(K), with location
- fractions of profile in preregistered dry, wet and near-saturated bands
- groundwater depth
- capillary-fringe descriptor and root-zone distance where definable
- wetting/drying-front position and strength under a preregistered algorithm
- distance to applicable boundary-switch threshold

### forcing — fixed before solve
- precipitation
- irrigation
- potential evaporation/transpiration or the canonical atmospheric demand quantities
- prescribed top/bottom flux/head values
- forcing rate-of-change descriptors
- active boundary-condition identities

### num_pre — numerical context known before solve
- requested dt
- grid spacing/geometry descriptors
- nonlinear method
- tolerances
- previous accepted-step iteration count
- previous rejection flag
- retry index
- previous solver/method

History fields MUST remain under `num_pre`; they MUST NOT be relabelled as physical predictors.

### outcome — unavailable to predictors
- converged
- admissible_final_state
- mass_balance_pass
- hidden_fallback_used
- nonlinear_iterations
- rejection
- retry_required
- residual trajectory where exposed
- increment/update trajectory where exposed
- damping/line-search events where exposed
- linear iterations where exposed
- conditioning proxy where technically meaningful
- wall/CPU time, explicitly secondary because execution environment confounds it
- accepted/final-state reference
- failure class

A trial is **reliably solvable** only when convergence, physical admissibility, mass-balance acceptance and intended boundary semantics all pass without unrecorded fallback.

## 7. Difficulty endpoints

No composite Hydrological Difficulty Index is preregistered.

Primary endpoints:
- reliable solve yes/no;
- nonlinear iteration count for comparable iterative methods;
- rejection/retry;
- maximum admissible timestep from a fixed checkpoint, `dt_star(method, checkpoint)`.

Secondary endpoints:
- residual contraction;
- linear iteration burden;
- conditioning proxy;
- computational time.

`dt_star` is the preferred cross-method robustness endpoint where method semantics permit comparison.

## 8. dt-star protocol

For each selected checkpoint/method, probe a frozen multiplicative timestep ladder around a reference dt, initially:

`{0.25, 0.5, 1, 2, 4} * dt_ref`.

If a success/failure bracket exists and failure semantics are monotone enough to make the concept meaningful, refine the bracket by deterministic bisection to a preregistered relative precision.

If success is non-monotone in dt, do **not** force a scalar `dt_star`; flag `NON_MONOTONE_SOLVABILITY` and retain the full response curve. Non-monotonicity is scientifically relevant and must not be hidden.

## 9. Counterfactual replay qualification

Before scientific data generation, qualification MUST prove:
1. restore reproduces the same pre-trial state bitwise or within a justified canonical tolerance;
2. method order does not change later counterfactual outcomes;
3. rejected/failed trials leave the source checkpoint unchanged;
4. forcing and boundary inputs are identical across methods for a counterfactual group;
5. diagnostic instrumentation does not alter accepted physics;
6. fallback is either disabled for the experiment or explicitly recorded and excluded from pure-method endpoints;
7. trial records are complete on success and failure;
8. deterministic reruns reproduce classifications.

## 10. Sampling target

Initial target: 6 regimes × 4 soils × 25 sufficiently distinct checkpoints = 600 physical checkpoints.

A nominal five-dt, three-method matrix gives 9,000 base attempts before local dt refinement. This is a target, not a claim of statistical independence.

Checkpoint selection MUST avoid pseudoreplication from adjacent timesteps. Selection is clustered/stratified in physical-state space using only pre-trial variables. Temporal neighbours that are effectively duplicate states must not count as independent checkpoints.

## 11. Analysis plan

No deep-learning model is part of the primary analysis.

Three predictor families are frozen:

**N, numerical-context model:** dt + numerical history.

**P, physical model:** physical state + forcing; no retry/previous-iteration information.

**PN, combined model:** physical state + forcing + numerical context.

Primary inferential contrast: out-of-sample information/performance gain `PN - N`, accompanied by uncertainty and effect sizes. A high in-sample classifier score is not evidence for H1.

Model classes should start with interpretable regression/GAM or similarly transparent methods and simple trees. More flexible ML may be used only as a secondary upper bound on predictability.

Variance/deviance decomposition must explicitly retain method effects and physical-state × method interactions.

## 12. Mandatory transfer tests

T1 **Leave-one-soil-out:** each soil family is a complete holdout in turn.

T2 **Leave-one-regime-out:** tests extrapolation; failure here is informative but is not by itself a kill criterion.

T3 **Cross-method:** derive physical relationships on method A and test direction/regime structure on method B, then reverse.

T4 **Resolution perturbation:** repeat a preregistered subset on an altered vertical discretisation. A hydrological regime claim must not depend entirely on one grid.

Random row-wise train/test splitting is prohibited as primary evidence.

## 13. Post-outcome regime labels

These labels are outcomes, never training inputs:

- **U universally benign:** independent methods remain comfortably inside their reliable envelope.
- **P shared physical-difficulty candidate:** multiple independent methods show concordant deterioration with the same pre-trial physical transition.
- **M method-sensitive:** large physical-state × method interaction.
- **F formulation-sensitive:** contrast is primarily between iterative Richards and alternative formulation such as RossFast.
- **X unresolved:** no stable classification.

The term “intrinsic physical difficulty” is prohibited until evidence supports a shared structure. Prefer “shared physical-difficulty candidate” during Phase 0.

## 14. Conditioning firewall

Linear-system conditioning and nonlinear difficulty MUST be reported separately. Poor linear conditioning cannot by itself establish nonlinear difficulty.

Where exposed, retain:
- nonlinear convergence/iteration information;
- Jacobian/linear-system conditioning proxy;
- linear iterations/time.

The analysis must distinguish nonlinear-basin/linearisation difficulty from linear-solve burden.

## 15. Survival criteria

The standalone DIFFICULTY hypothesis survives Phase 0 only if:

S1. Physical state/forcing provide material out-of-sample information beyond numerical context, with uncertainty reported.

S2. At least important physical relationships retain direction and useful information in leave-one-soil-out tests.

S3. At least one important physical transition has recognisable difficulty structure across two genuinely distinct iterative nonlinear methods.

S4. The surviving structure can be represented by a small, scientifically interpretable set of physical descriptors/regimes. Black-box accuracy alone does not satisfy S4.

No arbitrary percentage threshold will be invented after seeing results. Before final analysis, statistical estimands, uncertainty procedure and any decision thresholds must be frozen without inspecting the held-out outcomes.

## 16. Kill criteria

The intended standalone claim is killed if the dominant evidence shows any of:

K1. difficulty is effectively explained by dt and numerical history, with negligible independent physical information;

K2. physical relationships fail systematically under soil holdout and reduce to soil-specific maps;

K3. no meaningful shared physical structure survives comparison of independent nonlinear methods;

K4. apparent physical regime boundaries disappear under modest resolution perturbation without interpretable scaling;

K5. predictive skill depends primarily on solver-internal/post-start quantities;

K6. only high-dimensional black-box models recover signal while interpretable physical descriptors show no stable structure;

K7. apparent regimes are specific to SWAP5 implementation artefacts, especially boundary handling, rather than the represented hydrological transition.

K1/K2/K5/K6 terminate the intended physical-regime paper. K3 redirects, rather than automatically terminates, the scientific question toward method-dependent numerical difficulty if the evidence is strong and general.

## 17. Negative-result protection

A cross-method falsification is scientifically retained if physical state strongly structures difficulty within methods but the structures demonstrably disagree between methods over broad state space. The permissible conclusion is then about inseparability of hydrological state and numerical representation, not about a universal difficulty map.

No publication is guaranteed by this clause.

## 18. SWAP5 implementation boundary

Phase-0 instrumentation is research infrastructure, not production physics. It MUST:
- reuse canonical checkpoint/restore and trial semantics where available;
- avoid changing Richards physics, constitutive relations or production solver tolerances merely to improve the experiment;
- keep research-only derived descriptors outside canonical physical state;
- persist provenance sufficient to replay every record;
- bind any new research adapter to existing typed transactional interfaces rather than bypassing them.

Before implementation, perform a narrow authority trace over current canonical transaction, solver, RossFast and boundary contracts. If a required observation is not currently exposed, add the smallest observational seam possible and qualify non-interference.

## 19. Workunits

**DIF-P0A Authority binding:** map current canonical checkpoint/restore, trial execution, solver status, boundary state and RossFast envelopes to this protocol.

**DIF-P0B Record contract:** implement/serialize TrialDifficultyRecord v0 plus provenance and schema tests. No scientific outcomes.

**DIF-P0C Counterfactual replay harness:** restore one checkpoint into method/dt branches; prove isolation, order independence and deterministic recording.

**DIF-P0D Descriptor layer:** implement pre-trial physical descriptors and unit/identity tests. Freeze algorithms before outcome analysis.

**DIF-P0E Regime generator/selector:** construct/select R1-R6 without using solver outcomes.

**DIF-P0F Pilot qualification:** tiny blinded run to verify coverage, failure recording and dt probing. Pilot outcomes may tune infrastructure, not hypotheses or predictor definitions.

**DIF-P0G Frozen Phase-0 run:** generate the preregistered dataset.

**DIF-P0H Analysis:** execute N/P/PN, transfer tests, conditioning firewall and survival/kill adjudication.

No later workunit is admitted merely because the previous one produced a positive-looking result.

## 20. Evidence and anti-HARKing rules

- Preserve this preregistration commit SHA in every dataset/result.
- Any amendment after outcome access must be versioned and labelled POST-OUTCOME.
- Exploratory predictors are allowed only when labelled exploratory and cannot retroactively satisfy preregistered survival criteria.
- Failed trials are data and must not be silently dropped.
- Missingness/failure mechanisms must be reported.
- Phase-0 raw records are append-only.
- Scientific conclusions must report negative transfer tests alongside positive ones.

## 21. Admission decision

At the end of DIF-P0H assign exactly one:

- **ADVANCE_PHYSICAL_REGIME_PAPER**: S1-S4 supported, including meaningful cross-method structure.
- **ADVANCE_METHOD_INTERACTION_PAPER**: physical structure exists but H3 is falsified in a scientifically coherent, transferable way.
- **NARROW_PERFORMANCE_RESULT**: useful prediction exists but transfer/interpretability is insufficient.
- **STOP_DIFFICULTY_STANDALONE**: no defensible standalone numerical-hydrological novelty survives.

This decision is evidence-driven. SWAP5 instrumentation success is not a survival criterion.
