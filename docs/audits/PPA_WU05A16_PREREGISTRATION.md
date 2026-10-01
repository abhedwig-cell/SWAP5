# PPA-WU05-A16 preregistration — inner-Richards macropore callback prototype

Date: 2026-10-01

Status: `PREREGISTERED / RESEARCH_PROTOTYPE`

Baseline:
`research/ppa-wu05-a15-exchange-derivative@dec0211bbae0a8e57b539cb7a95bf47e3d4ebc54`

Canonical reconciliation:
`integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`.

Dependencies:

- corrected A11 source-faithful perched carrier;
- A14 qualified inner-callback architecture;
- A15 qualified source-faithful exchange derivative.

## Purpose

Prototype the unused `macropore_exchange_provider_t` as an explicit current-iterate
Reference-Richards callback and prove that HeadCalc can consume current-iterate macropore
rate and derivative information without acquiring ownership of persistent macropore state.

A16 is research only. No canonical admission is claimed.

## Interface change

The previously unused provider ABI may be changed because repository search found no
concrete implementations or active consumers.

The prototype interface shall receive:

- current pressure head;
- current constitutively consistent water content;

and return:

- exchange flux in the A6 sign convention, positive toward matrix;
- local diagonal derivative `dQexc/dh`;
- derivative availability;
- active flag.

Provider absence must retain the existing explicit Reference-Richards route.

## HeadCalc ownership

When the provider is associated:

- `vector_F` evaluates it from the current candidate `h/theta`;
- exchange is subtracted exactly once from the residual;
- `jacobian_F` subtracts the derivative from the diagonal;
- HeadCalc does not mutate provider continuation state.

The callback result is trial scratch only.

## Gates

### G1 — ABI and inactive preservation

A provider-absent explicit Reference-Richards solve remains bitwise identical on the
existing focused reference fixture.

### G2 — current-iterate invocation

A controlled test provider proves that callback inputs change when Newton/backtracking
candidate `h/theta` changes and that the provider is called from residual evaluation,
not only once before Newton.

### G3 — residual and Jacobian ownership

For an analytical callback with known `Q(h)` and `dQ/dh`, HeadCalc must compose:

`F = F_base - Q`

and:

`Jdiag = Jdiag_base - dQ/dh`

without duplicate source/sink ownership.

### G4 — actual A11/A15 provider feasibility

If G1-G3 pass, implement the smallest adapter from accepted read-only macropore context,
current matrix iterate and immutable rate configuration into A6/A11 rates plus A15
derivative.

The prototype must demonstrate a current-iterate perched rate in the previously falsified
A13 profile.

### G5 — state isolation

Calling the provider repeatedly with different trial iterates must leave the accepted
seven-field macropore continuation state bitwise unchanged.

## Fail conditions

A16 is falsified or blocked if the prototype requires:

- mutable committed state inside HeadCalc;
- legacy macropore globals;
- duplicate matrix source ownership;
- restart-schema expansion;
- hidden solver-specific persistent state;
- weakening solver/mass tolerances.

## Non-scope

- no production admission;
- no publication of macropore candidate from inside HeadCalc;
- no dynamic crack continuation update;
- no covering-layer extension;
- no RossFast;
- no parallel MultiSWAP.

## Decision states

- `QUALIFIED_INNER_CALLBACK_PROTOTYPE`;
- `QUALIFIED_INTERFACE_PROTOTYPE_ACTUAL_PROVIDER_FOLLOWUP_REQUIRED`;
- `REQUIRES_FURTHER_SOLVER_INTERFACE_WORK`;
- or `FALSIFIED_INNER_CALLBACK_PROTOTYPE`.
