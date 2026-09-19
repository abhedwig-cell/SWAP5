# DIF-P0A — canonical authority binding

**Status:** CLOSED, WITH ONE SCIENTIFIC PREREQUISITE BLOCKER  
**Preregistration:** `docs/publications/DIFFICULTY_PHASE0_PREREGISTRATION.md`  
**Authority inspected:** `integration/f-ci-canonical@187e30153c890151768e929170d14bb22af1d86d`  
**Research branch:** `research/difficulty-phase0-preregistration`

## Purpose

Bind the preregistered DIFFICULTY Phase-0 protocol to capabilities that actually exist in canonical SWAP5 before any scientific outcome dataset is generated.

This is an authority trace, not an implementation admission.

## Findings

### A. Counterfactual state isolation — AVAILABLE

Canonical `mod_transaction_reference` already provides the semantics needed for a research replay harness:

- `transaction_state_t%clone` defines model-owned state cloning;
- `transaction_model_t%capture_attempt_context` and `restore_attempt_context` separate worker/job-local rollback context from persistent physical state;
- `execute_reference_interval` clones a checkpoint before trial work;
- the external full/two-half route restores the same checkpoint context before independent candidate trajectories;
- rejection restores checkpoint context and prevents rejected candidates from becoming committed state.

**Binding:** DIF-P0C MUST reuse these semantics. It must not invent a second state-authority mechanism.

**Qualification still required:** the research harness must prove order independence, source-checkpoint immutability and deterministic replay for its concrete model binding.

### B. Solver request and pre-trial physical state — PARTLY AVAILABLE

`soil_water_solve_request_t` exposes before solve:

- parameter/grid binding;
- base pressure head and water content;
- ponding depth and groundwater level;
- top/bottom boundary modes and flux/head values;
- physical macropore flag;
- numerical tolerances/configuration;
- step duration;
- constitutive/source/sink/root/top-boundary provider bindings.

This is sufficient to bind the core TrialDifficultyRecord namespaces without reading post-start solver state.

### C. Constitutive physical descriptors — AVAILABLE THROUGH PROVIDER, NOT STORED STATE

The typed physical state intentionally does not own K, C or dK/dh. The constitutive provider is the correct authority for evaluating these quantities from the pre-trial state. The reference temporal-indicator code already demonstrates pre/post constitutive evaluation into water content, conductivity, capacity and dK/dh arrays.

**Binding:** DIF-P0D should evaluate research descriptors through the bound constitutive provider. It must not promote K/C/dKdh into canonical committed physical state.

### D. Solver outcomes and work counters — AVAILABLE

`soil_water_solve_result_t` and `soil_water_solver_diagnostics_t` expose:

- solve status and retry advice;
- candidate state;
- integrated mass-balance residual availability/value;
- optional native balance-rate residual;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- alternative solver calls;
- internal retries;
- route identity.

The transaction result additionally separates accepted versus total diagnostic work and owns transaction-level mass/temporal acceptance.

**Binding:** convergence is not equivalent to reliable solvability. The preregistered reliable-solve endpoint must compose solver status with the transaction/admissibility/mass contract.

### E. Residual trajectory and increment trajectory — NOT EXPOSED

Canonical diagnostics expose counts and terminal typed residual diagnostics, not a per-iteration residual trajectory or Newton-update trajectory.

The reference workspace owns residual/Newton scratch internally. Reading those arrays from outside the solver would violate ownership.

**Disposition:** these remain optional secondary endpoints in Phase 0. DIF-P0B/C must not block on them. If later scientific analysis requires them, introduce a separate minimal observational seam with explicit non-interference qualification. Do not instrument the frozen owner casually.

### F. Conditioning proxy — NOT CANONICALLY EXPOSED

The reference linear solve exposes solve/fallback behaviour but no canonical condition-number estimate.

**Disposition:** conditioning remains optional. Phase 0 can already maintain the conditioning firewall by reporting available linear-solve burden separately from nonlinear difficulty. A conditioning estimator requires a later governed observational workunit and is not prerequisite to dataset generation.

### G. Boundary-transition information — PARTLY AVAILABLE

Boundary identities and requested top/bottom flux/head are present in the request. Dynamic top-boundary results can expose regime, actual flux, surface head/conductivity, candidate ponding, evaporation/runoff and route where that provider is active.

However, a universal scalar “distance to boundary switch” is not a canonical field and cannot be inferred generically across all boundary implementations.

**Binding:** DIF-P0D must define boundary-specific prospective distance functions only for admitted boundary providers. Unsupported boundaries receive an unavailable value, not a fabricated common metric.

### H. Numerical history — AVAILABLE AT TRANSACTION/runtime LEVEL, REQUIRES RESEARCH ASSEMBLY

Current contracts expose current dt/tolerances plus trial and transaction diagnostics. Previous accepted-step iteration count, previous rejection and previous method are history, not physical state.

**Binding:** the research recorder may assemble these from the accepted execution history, but they remain under `num_pre`. No history field may leak into the physical predictor namespace.

### I. RossFast — ADMITTED BUT RESTRICTED ALTERNATIVE FORMULATION

F-ROSS22 records canonical production admission of the D3R RossFast kernel/wrapper without threshold retuning or reference mutation. The current wrapper is fail-closed and requires, among other restrictions:

- the fixed D3R grid/cell count;
- explicit top flux;
- prescribed bottom flux;
- no macropore;
- no root sink/dynamic top boundary/macropore provider;
- zero ponding;
- its admitted material/table binding.

F-ROSS25's corrected serial validation reports no RossFast route failure in its frozen experiment but substantial common-envelope loss with the Reference route. It explicitly forbids widening the state-local production forcing envelope from that evidence.

**Binding:** RossFast is useful for formulation-sensitive comparison only inside its common envelope. It cannot serve as the preregistered second independent iterative nonlinear method.

### J. Second independent iterative nonlinear method — NOT FOUND IN CURRENT CANONICAL AUTHORITY

A narrow repository trace found no admitted Modified Picard or L-scheme implementation and no second genuinely distinct iterative nonlinear Richards method suitable for H3.

This is the only material prerequisite blocker identified by DIF-P0A.

The preregistration already forbids implementing a new solver solely to rescue the paper. Therefore:

- DIF-P0B through DIF-P0F may proceed as infrastructure/pilot work without claiming H3;
- DIF-P0G, the frozen full Phase-0 run intended to adjudicate S3/H3, MUST NOT be admitted until an independent iterative method has legitimate scientific authority;
- RossFast comparisons may proceed as explicitly secondary `F formulation-sensitive` evidence.

## Required observational seams

No production-physics seam is required for the minimum viable Phase-0 dataset.

The minimum record can be built from:
1. typed solve request;
2. constitutive-provider evaluation at the immutable pre-trial state;
3. solver result/diagnostics;
4. transaction acceptance/mass result;
5. research-owned accepted numerical history.

Deferred optional seams:
- per-iteration residual trajectory;
- Newton increment trajectory;
- conditioning estimate.

These must not delay DIF-P0B/C.

## Concrete method identities for the first harness

Until a second iterative method is independently admitted:

- `REFERENCE_NEWTON`: frozen Reference Richards/HeadCalc route behind the typed solver service;
- `ROSSFAST_D3R`: alternative-formulation comparator, only when the exact common envelope is satisfied.

The recorder must reject any attempt to label RossFast as an independent nonlinear iterative method.

## DIF-P0B binding decisions

The JSON schema is a documentation contract. The executable record implementation should initially support:

- complete identity/provenance;
- pre-trial h/theta plus grid;
- pre-trial K/C/dKdh when the constitutive provider supports them;
- ponding and groundwater level;
- boundary identities/values;
- dt and numerical tolerances;
- research-owned prior-step history;
- terminal solve status and existing diagnostic counters;
- transaction mass/admissibility fields;
- explicit availability flags for optional diagnostics.

Do not encode unavailable optional diagnostics as zero.

## DIF-P0C replay qualification matrix

Before any pilot scientific interpretation, demonstrate for at least Reference Newton and, inside its envelope, RossFast:

| Qualification | Required result |
|---|---|
| same checkpoint replayed twice | identical pre-trial record |
| A then B vs B then A | method outcomes invariant to order within deterministic tolerance |
| failed/rejected branch | source checkpoint unchanged |
| dt branch replay | only dt/numerical context differs unless method contract requires otherwise |
| diagnostic recording on/off | accepted physical endpoint unchanged |
| forcing identity | exact same physical forcing contract per counterfactual group |
| fallback | explicit in route/counters, never hidden |
| failure record | complete identity + pre-trial namespaces + classified outcome |

## Admission result

**DIF-P0A = CLOSED_AUTHORITY_BOUND_WITH_H3_PREREQUISITE_BLOCKER**

Permitted next work:
- DIF-P0B executable TrialDifficultyRecord contract;
- DIF-P0C counterfactual replay harness;
- DIF-P0D descriptor layer;
- DIF-P0E prospective regime construction;
- DIF-P0F blinded infrastructure pilot.

Not yet permitted:
- claiming universal/shared physical difficulty;
- treating RossFast as H3 evidence;
- DIF-P0G final frozen run for S3 adjudication without a legitimate second iterative method;
- widening any RossFast or Reference application envelope.

## Scientific consequence

The repository is already much better suited to this experiment than a conventional monolithic model because candidate state, accepted state, numerical diagnostics and transaction acceptance are separated. That is experimental infrastructure, not the scientific novelty.

The real unresolved dependency is scientific rather than architectural: H3 needs an independent nonlinear method. If such a method cannot be justified independently of this publication, the preregistered decision logic forces the work toward method-specific or formulation-sensitive numerical hydrology rather than a universal difficulty claim.
