# TAB-HYD generated K0 provider production handoff

Date: 2026-09-23

Status: **PREREGISTERED HANDOFF — production implementation not yet admitted**

Proposed work unit: **TAB-HYD-K0-PROD01 — generated MvG-equivalent constitutive provider**

## 1. Purpose

Carry the qualified TAB-HYD K0 research result into one bounded production work unit without widening the scientific denominator.

The production question is:

> Can the currently admitted default analytical Mualem–Van Genuchten constitutive relation for `SWKIMPL=0` be represented by an internally generated, immutable raw-head table provider behind the existing typed constitutive-provider seam, preserving analytical MvG as the default/reference route and preserving current solver, transaction and application semantics?

This work unit is an **acceleration representation** of already admitted default-MvG physics. It is not admission of arbitrary user-supplied hydraulic tables.

## 2. Current authority

Reconcile from current canonical:

- `integration/f-ci-canonical@b7d9c976e9b474545d54fa79b71ae134c25da156`.

Research evidence authority:

- `research/tabulated-hydraulics-characterization@eb74b628bb277ce804b4a3ca2f066f531d5e23f3`;
- `TYPED_PROVIDER_RESEARCH_RESULT.md`;
- `GENERIC_TEMPORAL_INDICATOR_RESULT.md`;
- dynamic FMR44R characterization run `35818703618`;
- generated-provider break-even run `35538710173`.

The analytical default-MvG production provider remains the reference authority.

## 3. Frozen scientific denominator

The first production slice is deliberately limited to the currently admitted default-MvG / explicit-conductivity route.

Required:

- default Mualem–Van Genuchten relation already represented by the canonical analytical provider;
- `SWKIMPL=0`;
- no hysteresis;
- no arbitrary externally supplied table data;
- no legacy `SWSOPHY=1` file grammar;
- no inverse-table capability;
- no new hydraulic model family;
- no solver-policy change;
- no timestep-policy or retry-policy change;
- no tolerance retuning.

Parameter extensions that change the admitted constitutive relation, including unsupported `H_ENPR` or `KSATEXM` combinations, must fail closed unless separately qualified and admitted.

## 4. Frozen representation candidate

The qualified generated representation is:

1. 400 generated pressure-head rows per active hydraulic node/material;
2. physical pressure head `h` as runtime interpolation coordinate;
3. `ln(K)` as conductivity ordinate;
4. TSPACK preprocessing outside the nonlinear hot loop;
5. explicit analytical wet theta/C continuation;
6. explicit Ksat plateau and branch boundary;
7. constant dry extension;
8. bounds-safe interval location;
9. immutable preprocessed provider state reused across trials;
10. deterministic generation from the admitted typed MvG parameter authority.

The representation must not be retuned in response to performance tests without opening a new research candidate and repeating the scientific gates.

## 5. Existing typed seam

The canonical solver contract already exposes:

`constitutive_hydraulics_provider_t`

with vector evaluation of:

- water content;
- hydraulic conductivity;
- capacity;
- reserved conductivity derivative.

No new Richards residual ABI is required for this K0 slice.

Production selection, however, currently binds the analytical provider directly. The production work unit therefore needs an explicit and fail-closed provider-selection owner outside solver mathematics.

## 6. Required contract decision: timestep context

Research TAB-HYD-005 showed that the temporal-indicator mathematics is provider-agnostic, but the common provider contract cannot currently verify the existing invariant:

`provider timestep context == request%step_duration`.

Before production binding, the solver-contract owner must admit one of two minimal designs:

### Option A — explicit evaluation context

Pass the relevant timestep context explicitly to constitutive evaluation.

Properties:

- provider remains stateless with respect to timestep;
- temporal-indicator owner can evaluate the same provider under explicit context;
- no hidden rebind operation between trials.

### Option B — minimal context validation capability

Retain the current evaluation signature and add a generic capability such as:

`validate_context(step_duration)`

or equivalent immutable/bound-context query.

Properties:

- smaller ABI change;
- preserves the current bound-provider pattern;
- temporal-indicator owner can fail closed generically rather than concrete-type dispatch.

### Decision rule

Choose the smallest design that:

- reproduces the analytical provider route bit-/tolerance-equivalently;
- supports the generated provider without TAB-HYD-specific type checks;
- adds no measurable material overhead to the analytical reference route;
- makes invalid/mismatched timestep context fail closed.

This contract decision must be preregistered and independently reviewed before provider production binding.

## 7. Provider lifecycle and ownership

Generated table state belongs to immutable constitutive parameter/provider configuration.

Required lifecycle:

`typed MvG parameters → validate → generate table once → preprocess once → immutable provider → reuse across all trials/retries for that parameter set`.

Forbidden:

- regenerate tables on every Newton iteration;
- regenerate on every trial solely because `configure_parameters` is called;
- store committed hydrological state in the provider;
- let the provider decide acceptance/retry/rollback;
- hide mutable physical state in interpolation caches.

Research break-even evidence gives approximately:

- extra startup/preprocessing: `5.30 ms` for 30 nodes;
- amortization: about `8,860` 30-node vector constitutive evaluations;
- approximate provider table state: `657 KiB` for 30 nodes.

These are characterization numbers, not portable production guarantees.

## 8. Provider selection

The analytical provider remains default and reference.

The generated provider must be:

- explicitly selected through typed configuration/capability;
- opt-in during first admission;
- unavailable for unsupported parameter profiles;
- incapable of silently falling back to a different constitutive relation.

A failed generated-provider initialization must return a typed fail-closed status. It must not silently select the analytical provider inside an already-started table-designated trial.

## 9. Mandatory preservation invariants

The production slice must preserve:

- Reference Richards equations;
- accepted/retry semantics;
- transaction checkpoints and rollback;
- mass accounting;
- temporal-indicator formulas;
- boundary-condition ownership;
- process/source/sink ownership;
- analytical MvG default route;
- deterministic results for the analytical route when the generated provider is not selected.

No production admission may rely only on provider microbenchmarks.

## 10. Required qualification ladder

Use the following order. Failure at an earlier scientific gate blocks later performance claims.

### G1 — contract preservation

- analytical provider through the revised contract reproduces the current canonical analytical result;
- O0/O2 or equivalent compiler-configuration identity where existing owner gates require it;
- invalid timestep context fails closed.

### G2 — deterministic generation

Across the declared supported parameter envelope:

- finite and monotone generated table state;
- branch locations reproduced deterministically;
- no per-call allocation;
- identical generation for identical parameter authority.

### G3 — provider constitutive qualification

At minimum reproduce the current 30-Staring characterization envelope.

Current research reference values:

- theta max abs difference approximately `5.32e-5`;
- C max abs difference approximately `5.17e-5`;
- log10(K) max abs difference approximately `3.04e-4`.

Admission limits must be frozen before production qualification; do not derive them from the candidate result after the fact.

### G4 — Reference Richards solve

Reproduce the bounded coarse/loam/clay direct-solver profiles with:

- same nonlinear convergence class;
- same linear-solve count unless independently explained;
- mass preservation;
- pressure-head / theta / flux error within frozen limits.

### G5 — serialized Reference transaction runtime

Reproduce:

- provider-consistent initialization;
- accepted/retry semantics;
- mass ledger;
- unchanged ownership;
- bounded performance characterization.

### G6 — dynamic model-certificate trajectory

Reproduce the FMR44R positive prescribed-qbot gate or its current-canonical successor.

Research run `35818703618` is the current characterization reference.

### G7 — initialization and amortization

Measure provider construction and cache lifetime in the actual production owner.

Reject designs that rebuild immutable table state per trial.

### G8 — whole-Hupsel typed application gate

Use the existing M1-C3 exact whole-Hupsel application authority.

Required exact asset SHA-256:

`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.

Do not substitute a reconstructed archive, public copy, alternate parser or synthetic fixture.

This gate is currently externally blocked because the exact authorized distribution bytes are not materializable in the available execution context.

### G9 — independent qualification

Independent reviewer/gate must verify:

- no new physics;
- no parser leakage into solver/provider contracts;
- reference-provider preservation;
- fail-closed provider selection;
- evidence/source/commit bindings;
- no unsupported speedup generalization.

## 11. Performance evidence and claim boundary

Research currently supports:

- about 19% lower typed constitutive evaluation cost;
- material reductions in bounded Reference-Richards solves;
- material reductions in bounded serialized Reference runtime;
- millisecond-scale provider generation cost with finite break-even.

Do not convert these into a portable “SWAP5 is X% faster” claim.

The production claim, if admitted, must be scoped to the measured execution envelope and include initialization cost.

## 12. Explicit nonclaims

TAB-HYD-K0-PROD01 does not admit:

- generic user-supplied tabulated hydraulics;
- historical `SWSOPHY=1` compatibility;
- `SWKIMPL=1`;
- K/dKdh implicit-Jacobian production use;
- hysteresis tables;
- frost/macropore-specific table semantics;
- non-MvG hydraulic model families;
- universal MultiSWAP speedup.

## 13. K1 disposition

K1 remains a separate research/admission line.

The expanded K1 envelope is currently blocked by the analytical reference route: `loam_mid_free` with corrected `SWKIMPL=1` did not complete within 120 s, and a 240 s diagnostic matrix was abandoned during prolonged analytical execution.

Therefore K1 is neither admitted nor table-falsified. It is not a prerequisite for TAB-HYD-K0-PROD01.

## 14. Start/stop rule

Implementation may start only from a fresh branch off the then-current canonical after:

1. current canonical is reconciled again;
2. timestep-context contract choice is preregistered;
3. supported parameter envelope and admission error limits are frozen;
4. ownership of provider selection and immutable table cache is explicit.

Stop and return to research if:

- a supported parameter profile cannot generate a valid table;
- route selection changes transaction/solver semantics;
- dynamic certificate behavior cannot be made provider-generic without formula/policy changes;
- the analytical reference route changes;
- whole-application differences exceed the frozen envelope.

## 15. Current disposition

**RESEARCH_HANDOFF_READY / PRODUCTION_IMPLEMENTATION_HELD_PENDING_CONTRACT_PREREGISTRATION_AND_FINAL_ASSET_GATE**

No canonical production mutation is made by this handoff.
