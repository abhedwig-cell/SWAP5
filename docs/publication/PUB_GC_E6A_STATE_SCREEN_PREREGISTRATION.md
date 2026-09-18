# PUB-GC E6-A preregistration — accepted-state response geometry screen

## Status

**PREREGISTERED BEFORE E6-A EXECUTION**

Date: 2026-09-18.

Canonical baseline:

`integration/f-ci-canonical@5d298c221caf4dbb917495f6e6a8718105df7208`

Publication line: PUB-GC / COUPLE.

## Purpose

E3 and E3-R established a well-qualified weak-feedback control. Increasing flux and window length alone did not produce a materially large groundwater-head correction before the prescribed-head SWAP corrector reached its transaction envelope.

E6 therefore changes the **accepted hydrological state** rather than relaxing any numerical tolerance.

E6-A is a component-only screen. It asks:

1. which initial pressure-head profiles admit the real SWAP predictor at materially larger vertical fluxes;
2. how wide the prescribed-head corrector domain remains around the resulting predictor reference head;
3. whether a different accepted state produces a qualitatively different finite-window response geometry suitable for a later live-MODFLOW E6-B comparison.

E6-A does not yet make a groundwater-coupling performance claim.

## Frozen numerical and physical configuration

Unchanged from the admitted F-GC44/E3 fixture unless explicitly varied below:

- real FMR/reference Richards backend;
- same four-node soil discretization;
- same Mualem–van Genuchten material parameters;
- root extraction inactive;
- drainage inactive;
- macropore flow inactive;
- snow, frost and soil temperature inactive;
- transaction tolerances, retry budget and temporal indicator budget unchanged;
- no publication/commit of any E6 diagnostic candidate.

Window duration is fixed at:

```text
DeltaT = 1e-3 day = 86.4 s
```

This is long enough to have produced a measurable E3/E4 response while retaining an admitted predictor/corrector domain in the baseline state.

## Accepted-state axis

The initial pressure-head profile remains hydrostatic in the qualification geometry but is shifted by changing its top-node pressure head `H0`.

Frozen values:

```text
H0 = -150 cm
     -75 cm   [existing F-GC44/E3 baseline]
     -25 cm
     -10 cm
```

All node pressure heads are shifted by the same amount relative to the existing one-centimetre node-distance profile.

This axis is described as **initial pressure-state wetness**, not as a calibrated regional groundwater-table depth. The fixture's diagnostic `groundwater_level` field is not used to reinterpret these states as field water-table elevations.

## Predictor flux axis

For every accepted state:

```text
q_top = q_bot =

1e-6
1e-4
1e-2
1e-1
1e0  cm/day
```

Keeping top and bottom predictor flux equal preserves the simple through-flow structure of the qualification fixture while allowing the admitted flux envelope to be tested at different initial water states.

No failed flux is retried with relaxed tolerances.

Total predictor screen:

```text
4 states x 5 fluxes = 20 cases.
```

## Prescribed-head corrector probes

For every predictor-ready case, run independent corrector trials from the same immutable accepted origin at:

```text
H = H_ref +/- deltaH

deltaH =
1e-6
1e-5
1e-4
1e-3 m
```

The positive and negative probe are each executed as alternative trials over the same physical interval and then discarded.

For each probe record:

- READY / bounded failure;
- q_SWAP;
- integrated bottom exchange;
- storage change only if available without changing the production participant API;
- authoritative revision/time/ledger tuple before and after discard.

The canonical production participant does not expose the full corrector trial mass carrier. E6-A therefore does **not** add such a production API solely for publication diagnostics. Corrector admissibility is the existing accepted-whole-window transaction result; predictor mass completeness/residual remains the explicit mass diagnostic used in the E6-A selection screen.

No asymmetric pair is converted into a centred derivative.

## Primary E6-A outputs

Per predictor case:

- `H0`;
- predictor flux;
- predictor READY/failure status;
- predictor reference head;
- current supplied response `u_A`;
- predictor `q_bot` and `q_u`;
- predictor storage change and mass residual.

Per head probe:

- offset from `H_ref`;
- trial READY/failure;
- q_SWAP and integrated bottom transfer;
- trial storage change where observable;
- zero-authority check after discard.

## State-selection rule for E6-B

E6-B is not allowed to choose a case because it gives the largest coupling correction after observing MODFLOW.

A state/flux pair becomes an E6-B candidate only if:

1. predictor initialization is READY;
2. both signs of the `1e-4 m` head probe are READY;
3. predictor mass accounting is complete and its residual is finite;
4. all discarded corrector trials preserve zero authoritative state/mass.

Among qualifying cases, select the **largest predictor flux**.

If several states qualify at the same largest flux, select the **wettest state**, i.e. the least negative `H0`.

This deterministic rule is fixed before E6-A output.

If no state exceeds the previously demonstrated `1e-4 cm/day` predictor level while retaining the +/-1e-4 m corrector domain, E6-A is reported as a negative state-extension result and E6-B is not constructed from this route.

## Interpretation

A wetter initial state may admit larger fluxes or change response sensitivity, but no monotonic result is assumed.

A predictor-ready case with a narrow/asymmetric corrector domain is not called a stronger usable coupling state.

E6-A can therefore end in three scientifically meaningful outcomes:

- **EXPANDED_STATE_DOMAIN** — a state admits substantially larger flux and a useful corrector neighbourhood;
- **PREDICTOR_ONLY_EXPANSION** — predictor capacity increases but corrector domain remains restrictive;
- **NO_USEFUL_EXPANSION** — accepted-state shifting does not create a better strong-coupling test regime.

All are reportable; none may be changed by numerical tolerance relaxation.


## Execution provenance checkpoint

Added after preregistration and before interpretation of E6-A output. The screen is executed as an ownership-disjunct component characterization while the separately preregistered active-drainage E6 route is being diagnosed. No result from that route is used to alter this screen, its state/flux matrix or its deterministic E6-B candidate rule.

Current canonical is `integration/f-ci-canonical@71626be59b81d00a3fd6a5d5a561febe9b5023b8`. The post-baseline canonical delta does not alter the E6-A qualification-only state-screen contract or its production physics inputs.
