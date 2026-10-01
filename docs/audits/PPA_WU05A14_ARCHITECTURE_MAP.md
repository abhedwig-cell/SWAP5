# PPA-WU05-A14 architecture map — inner-Richards macropore evaluation

Date: 2026-10-01

Status: `QUALIFIED_ARCHITECTURE_MAP`

Baseline: corrected A11 carrier on
`research/ppa-wu05-a14-inner-richards-macropore-design`.

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

## Exact legacy ordering

Exact SWAP 4.3.1/B1.11 executes macropore exchange inside the Richards nonlinear path:

1. `headcalc -> vector_F(1|2)`;
2. `vector_F -> MACROPORE(2)`;
3. `MACROPORE(2) -> MACRORATE(1)`;
4. the resulting `QExcMpMtx` is subtracted from the matrix residual;
5. `headcalc -> jacobian_F`;
6. `jacobian_F -> MACROPORE(3)`;
7. `MACROPORE(3) -> MACRORATE(2)`;
8. `dFdhMp` is subtracted from the Newton diagonal.

Thus the exact source contract is **rate plus local derivative at the current nonlinear
iterate**.

## Exact derivative semantics

For saturated exchange, SATFLOW stores the local head difference used by the rate
calculation and then forms a diagonal derivative from the accepted/current rate divided by
that head difference.

For unsaturated absorption, MACRORATE likewise contributes a local `dFdhMp(ic)` derived
from the active sorptivity or Darcy branch.

B1.11 therefore does not treat macropore exchange as a head-independent source term.

A flux-only inner callback would omit source-owned Newton information and is not an exact
replacement.

## Current SWAP5 solver structure

### Source/sink provider

The explicit `source_sink_provider_t` receives pressure head and water content, but
HeadCalc evaluates it once before the nonlinear loop and labels the resulting source/sink
arrays constant for the timestep.

It is therefore **not** suitable for current-iterate macropore exchange without changing
its established semantics.

### Existing macropore hook

`hydraulic_evaluation_context_t` already contains:

`class(macropore_exchange_provider_t), pointer :: macropore`

and the solver contract already declares a `macropore_exchange_provider_t`.

Repository search finds no implementation and no active consumer of this interface.

This unused hook is the narrowest architecture surface for A14.

### Current hook deficiency

The current abstract signature receives only:

- pressure head;

and returns:

- exchange flux;
- active flag.

That is insufficient for the exact A11/B1.11 route because:

1. `CritUndSatVol` uses current water content;
2. the exact Newton path requires `dQ/dh`;
3. HeadCalc currently never invokes the hook.

## Candidate interface

The smallest source-complete interface is conceptually:

`evaluate(pressure_head, water_content, exchange_flux, dexchange_dhead, derivative_available, active)`

where:

- `pressure_head(:)` is the current nonlinear iterate;
- `water_content(:)` is the constitutively consistent current iterate already available
  in HeadCalc;
- `exchange_flux(:)` has the existing A6 sign convention, positive toward matrix;
- `dexchange_dhead(:)` is the local diagonal derivative of that exchange rate;
- `derivative_available` is fail-closed for a route that requires Newton correction;
- `active` allows zero-cost inactive use.

No continuation state is returned or mutated.

## HeadCalc insertion points

For the explicit-provider route only:

### Residual

After current `state%h` and `state%theta` are consistent, and during every
`vector_F` evaluation:

1. evaluate the macropore provider;
2. subtract `exchange_flux(1:NN)` from the residual exactly once.

This mirrors:

`residual -= QExcMpMtx`.

### Jacobian

Use the derivative from the **same current iterate** and subtract it from
`dfdh_main(1:NN)`.

This mirrors:

`dfdh_main -= dFdhMp`.

The callback must be reevaluated whenever a backtracking candidate changes `h/theta`
before `vector_F(2)`.

## State and lifetime ownership

The provider may contain immutable/referenced trial context:

- accepted seven-field macropore state;
- immutable geometry/configuration;
- step forcing;
- current step duration;
- A11/A6 rate parameters.

It may allocate worker-local scratch.

It must not mutate:

- accepted macropore continuation state;
- committed matrix state;
- restart payload;
- sorptivity history;
- accepted geometry/history.

The current nonlinear iterate is an input only.

After solver convergence, the transaction layer remains responsible for constructing and
publishing the macropore candidate from the converged rate receipt.

Rejected attempts simply discard provider/workspace scratch.

## Relationship to A6/A11

The provider should not duplicate macropore physics.

It should adapt current `h/theta` plus accepted macropore context into the existing A6
rate bundle and A11 perched carrier.

A derivative companion is required. Existing A6 rate code currently qualifies rates, not
the full source `dFdhMp` surface. Therefore derivative migration/qualification is a
separate prerequisite before a production inner callback can be admitted.

## Architecture decision

The inner-Richards route is feasible without giving HeadCalc ownership of persistent
macropore state.

However, it **requires an explicit solver-interface extension**:

1. wire the presently unused macropore provider into `vector_F`;
2. extend its contract with current water content;
3. expose source-faithful local `dQ/dh`;
4. retain all continuation publication outside the solver.

Decision:

`FEASIBLE_INNER_RATE_CALLBACK_DESIGN_REQUIRES_SOLVER_INTERFACE_EXTENSION_AND_DERIVATIVE_MIGRATION`

This is an architecture result, not production admission.
