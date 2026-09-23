# F-TAB02 generated K0 hydraulics provider — production handoff

Date: 2026-09-23

Research source: `research/tabulated-hydraulics-characterization@eb74b628bb277ce804b4a3ca2f066f531d5e23f3`

Canonical authority at handoff: `integration/f-ci-canonical@b7d9c976e9b474545d54fa79b71ae134c25da156`

Status: **READY_FOR_SEPARATE_PRODUCTION_PREREGISTRATION**

This document closes the TAB-HYD interpolation/performance research line and defines the exact boundary for a separately owned production work unit.

## Capability to admit

The target capability is a **generated default-MvG acceleration provider for the already admitted K0 constitutive regime**.

It is not:

- generic user-supplied `SWSOPHY=1` table input;
- a restoration of legacy `numtab/sptab/ientrytab` globals;
- a new soil-hydraulic constitutive model;
- a production `SWKIMPL=1` admission;
- a solver-policy change.

The generated provider must remain numerically subordinate to the admitted analytical default-MvG authority.

## Research authority carried into the work unit

The following conclusions are closed enough to be treated as input evidence rather than reopened hypotheses.

### Representation

The qualified generated representation is:

- 400 physical pressure-head knots over the continuous branch;
- knots distributed uniformly in `log10(-h)`;
- raw physical pressure head as the runtime interpolation coordinate;
- theta as direct ordinate;
- `ln(K)` as conductivity ordinate;
- TSPACK preprocessing;
- explicit wet theta/C branch at the qualified wet boundary;
- explicit Ksat plateau;
- bounds-safe interval location;
- preprocessing outside the trial/nonlinear hot loop.

### Accuracy

Bounds-safe qualification over the 30 available Staring parameter rows gives approximately:

- max abs theta error: `5.32e-5`;
- max abs C error: `5.17e-5`;
- max abs log10(K) error: `3.04e-4`.

The localized `dK/dh` differences near branch transitions remain a K1 concern and do not block K0.

### Performance

Reproduced research evidence shows:

- typed provider evaluation: about **19% lower constitutive cost**;
- direct Reference-Richards K0 calls: about **27-31% lower bounded solve cost**;
- 40-node serialized Reference runtime: about **28-31% lower trial cost**;
- preprocessing break-even: approximately **8,860 30-node constitutive vector evaluations**.

These are execution-envelope results, not portable whole-model percentages.

### Dynamic transaction/certificate

Current-canonical run `35818703618` passed the bounded positive-qbot transaction/certificate gate for both the analytical authority and the generated table provider after provider-consistent t0 water-content initialization.

The table route preserved:

- accepted transaction;
- hard mass gate;
- temporal-certificate availability;
- head budget;
- total-in/total-out accounting;
- nearby unsupported bottom-mode fail-closed behavior.

## Mandatory production invariants

F-TAB02 must preserve all of the following.

1. **Analytical authority remains available and unchanged**
   - `b110_default_mvg_provider_t` remains the reference provider.
   - Generated-table selection is explicit and opt-in.
   - No benchmark-specific changes may be made to the analytical provider.

2. **No new physical state**
   - Generated tables and interpolation metadata are immutable numerical representation state.
   - They are not committed hydrological state.
   - They do not participate in accept/retry/rollback as physical state.

3. **Persistent provider lifetime**
   - Table generation/preprocessing occurs at parameter/provider materialization time.
   - It must not be repeated per nonlinear evaluation, per trial, or per retry.
   - Ownership must permit amortization across the actual application/MultiSWAP lifetime.

4. **Existing typed constitutive seam**
   - Use `constitutive_hydraulics_provider_t`.
   - Do not add a parallel solver-specific constitutive API unless independent authority proves the existing seam insufficient.

5. **Fail-closed selection**
   - Unsupported constitutive options, invalid parameters, invalid table generation, or missing provider context must reject the route explicitly.
   - Never silently fall back from generated table to analytical MvG within an active trial.

6. **K0-only production scope**
   - Production admission is restricted to the current admitted `SWKIMPL=0` regime.
   - The reserved derivative output does not imply K1 admission.

7. **No legacy table-input revival**
   - Generic external `SWSOPHY=1` remains outside F-TAB02.
   - Legacy table files and globals must not become the production ownership model.

## Required implementation slices

### F-TAB02-A — immutable generated-provider state

Own:

- deterministic generation from typed default-MvG parameters;
- immutable raw-head400 tables;
- preprocessing metadata;
- validation of monotonicity, finiteness and branch metadata;
- provider initialization failure semantics.

No provider selection yet.

### F-TAB02-B — typed provider implementation

Implement a production-facing provider behind `constitutive_hydraulics_provider_t`.

Required outputs:

- theta;
- C;
- K;
- K0-compatible derivative slot semantics consistent with the common contract.

Qualification must compare directly against the analytical provider over the declared parameter envelope.

### F-TAB02-C — provider selection and lifetime ownership

Add explicit configuration/selection at the application/runtime composition layer.

Must prove:

- analytical route remains default/reference;
- generated provider is bound once per immutable parameter authority;
- retries reuse the same immutable provider state;
- selection survives MultiSWAP ownership without hidden global state;
- no production reachability of legacy `SWSOPHY=1` is introduced.

### F-TAB02-D — transaction and temporal qualification

Repeat the current-canonical dynamic transaction/certificate qualification with the production-facing provider.

Must include:

- accepted transaction;
- mass accounting;
- temporal indicator/certificate;
- rollback/retry preservation;
- unsupported-neighbor fail-closed tests.

### F-TAB02-E — performance qualification

Measure at minimum:

- provider-only cost;
- Reference-Richards solve cost;
- serialized runtime cost;
- provider construction/preprocessing cost;
- break-even versus application lifetime.

Performance qualification must report both absolute timing and paired relative timing.

### F-TAB02-F — whole-application gate

Final application admission uses the exact authorized whole-Hupsel authority already established by canonical M1-C3.

Current blocker:

`BLOCKED_EXTERNAL_EXACT_ASSET_BYTES_UNAVAILABLE`

Required immutable archive SHA-256:

`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`

No public reconstruction, derived audit archive, alternate parser fixture, or synthetic case may substitute for this gate.

## Stop conditions

The production work unit must stop rather than widen scope if any of these occurs:

- generated K0 provider changes accepted hydrological trajectory beyond preregistered limits;
- provider construction cannot be amortized under real application ownership;
- common constitutive contract proves insufficient and a new ABI would be required;
- temporal or transaction semantics depend on provider-specific hidden state;
- exact whole-Hupsel authority remains unavailable at the final gate.

## Explicit nonclaims

F-TAB02 does not admit:

- arbitrary external tabulated soil hydraulics;
- `SWSOPHY=1` production input;
- K1 / implicit-conductivity production;
- a universal 20-30% whole-SWAP speedup;
- byte-exact equivalence to the unavailable historical B0 runtime.

## Recommended work branch

`work/f-tab02-generated-k0-provider`

Start from the current `integration/f-ci-canonical` at work-unit creation time, not from the research branch. Reuse research code only by deliberate clean-room transfer of the qualified representation and tests; do not merge the research branch wholesale.
