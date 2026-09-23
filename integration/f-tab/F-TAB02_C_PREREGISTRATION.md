# F-TAB02-C provider selection and lifetime preregistration

Date: 2026-09-23

Status: **PREREGISTERED — implementation held until F-TAB02 G1–G3 pass**

Canonical start: `a2d99ddd149ffaa422d9c422f96bd66e92c8555d`.

## Selection model

Add an explicit typed constitutive-provider mode to
`fmr_b110_physical_parameters_t`:

- analytical default-MvG = default/reference;
- generated default-MvG = explicit opt-in.

Do not reuse `SWSOPHY` and do not reinterpret
`tabulated_hydraulics_active`; those remain separate legacy/generic-table
capabilities and stay fail closed in this work unit.

## Ownership

The serialized Reference model retains its existing concrete analytical
provider unchanged.

A second, optional concrete generated-provider object is owned by the model and
is exposed to the solver only through the existing polymorphic
`request%evaluation%constitutive` pointer.

This avoids changing solver mathematics or the analytical provider storage
layout.

## Immutable cache rule

Generated provider state is cached by immutable parameter authority.

For an already cached `parameter_set_id`:

- identical parameter shape and exact parameter values reuse the provider;
- mutation under the same parameter-set identity fails closed;
- a new parameter-set identity may materialize a new generated provider.

Table generation/preprocessing must not occur per trial/retry.

Only timestep context is rebound per solve attempt.

## First selection envelope

Generated mode is admitted only when all are true:

- `SWKIMPL=0`;
- `SWSOPHY=0`;
- `tabulated_hydraulics_active=.false.`;
- `H_ENPR=0`;
- KSATEXM inactive in the core F-TAB02-C slice;
- no unsupported constitutive family flags.

The bounded KX05 KSATEXM extension is a later sub-slice after the core selection
gate closes.

## Failure semantics

Generated-provider initialization failure leaves the generated provider
unavailable and the generated-designated route fails closed.

There is no silent fallback to analytical MvG after generated mode has been
selected.

Analytical mode remains bitwise/reference-preserving by default.

## C gates

C1 — default preservation:
existing configurations with no new selection field set use analytical MvG and
reproduce current owner gates.

C2 — explicit selection:
generated mode binds the generated provider through
`request%evaluation%constitutive` without changing Richards or transaction
APIs.

C3 — persistent lifetime:
repeated configure/trial calls with identical parameter authority show one
provider materialization and reuse across retries.

C4 — fail closed:
invalid mode, unsupported profile, mutated same-ID authority, or failed
generated initialization cannot execute by analytical fallback.

No C implementation starts until G1–G3 are green.
