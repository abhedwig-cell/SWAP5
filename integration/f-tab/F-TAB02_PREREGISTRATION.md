# F-TAB02 generated K0 provider — production preregistration

Date: 2026-09-23

Status: **PREREGISTERED — G1/G2/G3 implementation authorized on this work branch only**

Canonical start authority:

`integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`

Research handoff authority:

`research/tabulated-hydraulics-characterization@f28cc15f1d26bf97c2e72d02dc716d8927068e8d`

## Capability

Implement an opt-in, internally generated default-MvG K0 constitutive provider behind the existing typed `constitutive_hydraulics_provider_t` seam.

This is a numerical representation of the already admitted default Mualem–Van Genuchten constitutive relation. It is not generic table input.

## Frozen first-slice envelope

Required:

- `SWKIMPL=0`;
- default MvG model only;
- `H_ENPR=0`;
- no KSATEXM in F-TAB02-A/B/C core;
- no hysteresis, frost, macropore or external user table input;
- 400 generated rows per active node;
- raw physical `h` interpolation coordinate;
- theta direct ordinate;
- `ln(K)` ordinate;
- qualified TSPACK preprocessing/evaluation;
- explicit wet theta/C continuation;
- explicit Ksat plateau;
- constant dry extension;
- immutable provider state after initialization.

The separately qualified bounded F-SI39/KSATEXM extension is deferred until the core G1–G3 route passes.

## Frozen G3 error limits

The production implementation must remain within:

- theta max abs <= `1.0e-4`;
- C max abs <= `1.0e-4`;
- log10(K) max abs <= `5.0e-4`;

over the 30-Staring characterization envelope.

These limits are frozen before production qualification and are not to be relaxed in response to results.

## Timestep context

Adopt the qualified generic capability:

`context_compatible(step_duration) -> logical`

Semantics:

- base provider default: fail closed;
- analytical MvG override: compatible only with its bound timestep;
- generated provider override: same rule;
- existing hot `evaluate(...)` ABI unchanged;
- temporal-indicator owner performs the generic capability check;
- mismatch fails closed.

## Provider lifecycle

Generated tables are immutable numerical configuration state.

Generation/preprocessing must occur once at provider materialization and be reused across nonlinear evaluations, trials and retries. No physical/committed state is stored in the provider.

## G1–G3 gates

### G1 contract preservation

- analytical route remains reference/default;
- analytical constitutive results unchanged;
- generic context mismatch fails closed;
- hot evaluate ABI unchanged.

### G2 deterministic generation

For identical typed MvG authority:

- identical generated knots/ordinates/metadata;
- finite strictly increasing h/theta/logK branches;
- no per-call allocation;
- unsupported parameter profiles fail closed through typed status.

### G3 constitutive qualification

Compare production generated provider directly against canonical analytical MvG over the 30-Staring envelope using the frozen limits above.

## Explicit holds

Not authorized in this slice:

- production provider selection in the application owner before G1–G3 pass;
- generic `SWSOPHY=1` input;
- K1;
- whole-Hupsel admission;
- performance claim beyond characterization.

Final G8 whole-Hupsel remains externally blocked on the exact authorized asset SHA-256
`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.
