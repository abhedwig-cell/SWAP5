# PPA-WU05-A14 result — inner-Richards macropore rate architecture

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_ARCHITECTURE_RESULT`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

Research branch evidence:
`research/ppa-wu05-a14-inner-richards-macropore-design@bf530033e68498cdd684f5f42459d50ff520fccd`.

## Decision

`FEASIBLE_INNER_RATE_CALLBACK_DESIGN_REQUIRES_SOLVER_INTERFACE_EXTENSION_AND_DERIVATIVE_MIGRATION`

The exact legacy ordering can be represented in SWAP5 without transferring ownership of
persistent macropore state into HeadCalc.

The required architecture is a stateless/trial-local nonlinear macropore exchange provider
that is evaluated from the current Richards iterate.

## Qualified findings

### 1. Outer accepted-state seeding is not sufficient

A13 demonstrated a positive source-faithful perched accepted-state exchange but zero
retained serialized macropore storage change. Another outer-predictor tuning is therefore
not the next justified route.

### 2. Existing source_sink is the wrong lifecycle

The current explicit `source_sink_provider_t` is evaluated once before the nonlinear
loop and its arrays are treated as constant for the timestep.

It cannot reproduce B1.11 `MACROPORE(2)` calls at every residual evaluation without
changing the established source/sink contract.

### 3. SWAP5 already has the correct architectural slot

`hydraulic_evaluation_context_t` already contains an unused
`macropore_exchange_provider_t`.

Repository search found no concrete implementers and no active consumers.

This is the narrowest explicit interface to extend rather than overloading drainage,
generic source/sink or constitutive providers.

### 4. Current macropore provider ABI is insufficient

Its present signature has pressure head only and returns exchange flux plus an active flag.

Exact perched detection needs the current constitutively consistent water content for
`CritUndSatVol`.

Exact B1.11 Newton treatment also requires a local exchange derivative.

### 5. Exact insertion point is vector_F / jacobian_F

Current HeadCalc already has constitutively consistent candidate `state%h` and
`state%theta` before each `vector_F(2)` backtracking evaluation.

Exact B1.11 calls `MACROPORE(2)` from `vector_F`, subtracts `QExcMpMtx` from the
matrix residual, and then calls `MACROPORE(3)` from `jacobian_F` to subtract
`dFdhMp` from the Newton diagonal.

The SWAP5 callback therefore belongs at those same conceptual points.

### 6. Flux-only callback is source-incomplete

Exact `MACRORATE(2)` produces local diagonal derivatives for saturated and unsaturated
matrix/macropore exchange.

Ignoring those terms would alter the nonlinear method and would need its own numerical
qualification. It must not be silently treated as source-equivalent.

## Candidate contract for the next workunit

The smallest source-complete callback has current-iterate inputs:

- `pressure_head(:)`;
- `water_content(:)`;

and outputs:

- `exchange_flux(:)`, positive toward the matrix;
- `dexchange_dhead(:)`, local diagonal derivative;
- derivative availability;
- active flag.

The implementation may read accepted macropore continuation state and immutable
configuration, but may not mutate them.

Rate and derivative scratch remain worker/trial-local.

After convergence, existing transaction code remains owner of candidate macropore
integration, history publication, rejection and restart.

## Interfaces affected

A production implementation would touch:

- `macropore_exchange_provider_t` in the solver contract;
- explicit HeadCalc provider activation;
- `vector_F` residual composition;
- `jacobian_F` diagonal composition;
- a provider adapter from current iterate plus accepted A11/A6 context;
- derivative migration/qualification from exact B1.11.

No persistent-state or restart schema change is required by the architecture itself.

## Invariants

The design preserves:

- committed state remains outside the solver;
- rejected attempts publish nothing;
- matrix/macropore exchange has one owner on each side of the internal transfer;
- Full Richards remains the reference path;
- existing A8/A9/A10 production paths need not change when the provider is absent.

## What A14 does not claim

A14 does not claim:

- an implemented inner callback;
- qualified A6 derivative migration;
- nonlinear convergence equivalence;
- serialized perched production admission;
- canonical admission.

Those belong to follow-on workunits.

## Next safe workunit

The next bounded unit is **A15 — source-faithful macropore exchange derivative migration**.

It should recover and qualify the exact B1.11 `dFdhMp` semantics against A6 rates before
any HeadCalc callback is wired into production.

Only after A15 is qualified should a callback prototype be connected to
`vector_F/jacobian_F`.

The frozen Status-A denominator remains unchanged.
