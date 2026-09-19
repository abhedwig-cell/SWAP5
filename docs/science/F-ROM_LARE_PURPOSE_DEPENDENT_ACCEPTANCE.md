# F-ROM-LARE purpose-dependent hydrological acceptance framework

## Status

Research framework only. No reduced model, LARE closure, or production solver is authorized by this document.

## Core distinction

A reduced hydrological model is not an alternative numerical solver.

An alternative numerical solver that targets the same Richards solution is appropriately judged against strict numerical and hydrological equivalence.

A deliberately reduced hydrological model is judged against the information and response fidelity required by a declared application.

Therefore the primary question is not:

> How close is the reduced model to every Richards state variable?

It is:

> Which hydrological distinctions must be preserved for this application, on which spatial and temporal scales, and which departures are immaterial to the decision or coupled response?

## Why no universal scalar threshold is used

Hydrological model-evaluation literature repeatedly warns against treating a single aggregate efficiency value or universal threshold as a purpose-independent adequacy test.

Relevant background includes:

- Knoben, Freer & Woods (2019), *Technical note: Inherent benchmark or not? Comparing Nash-Sutcliffe and Kling-Gupta efficiency scores*, HESS 23, 4323-4331, https://doi.org/10.5194/hess-23-4323-2019.
- Clark et al. (2021), *The Abuse of Popular Performance Metrics in Hydrologic Modeling*, Water Resources Research 57, e2020WR029001, https://doi.org/10.1029/2020WR029001.
- Ritter & Muñoz-Carpena / related hydrological performance literature: model adequacy should be evaluated against explicit benchmarks and the intended prediction, not a universal goodness-of-fit number.

RS1 therefore uses a vector acceptance envelope. A candidate may be acceptable for one purpose and outside domain for another.

## Structural requirements common to all purposes

These are not relaxed by application.

1. **Mass conservation**
   - explicit water ledger;
   - no hidden correction flux;
   - no systematic creation or destruction of water.

2. **State validity**
   - reconstructed or published physical states remain within declared physical bounds;
   - nonfinite or physically impossible states fail closed.

3. **Deterministic restartability**
   - accepted reduced state can be persisted and restarted without hidden solver history unless such memory is explicitly part of the model state.

4. **Domain declaration**
   - `OUTSIDE_QUALIFIED_DOMAIN` is an allowed result;
   - no silent extrapolation outside the tested regime.

## Purpose classes

### GW-R: regional groundwater coupling

Primary information:

- recharge and capillary exchange aggregated to the groundwater coupling interval;
- systematic exchange bias over weeks to seasons;
- storage change relevant to groundwater feedback;
- drainage-versus-capillary direction;
- groundwater response after the exchange is passed downstream.

Fast sub-step profile details are not automatically required.

The critical temporal benchmark is the coupling interval, not the internal Richards timestep.

### GW-D: dynamically coupled shallow-groundwater response

Primary information:

- instantaneous or sub-daily bottom exchange;
- flux sign;
- drainage-to-capillary and capillary-to-drainage reversal timing;
- storage redistribution controlling subsequent exchange;
- groundwater-level feedback where prognostic.

This purpose is stricter than GW-R.

### AG-WB: agricultural water balance and drought

Primary information:

- root-zone storage;
- cumulative and mean actual transpiration;
- cumulative soil evaporation;
- capillary contribution to root-zone supply;
- drought-stress onset, duration and recovery;
- irrigation-relevant state.

Nodewise pressure-head equivalence outside the root-relevant domain is not automatically required.

### EVT: rapid infiltration, ponding and runoff

Primary information:

- infiltration capacity;
- wetting-front or equivalent transition timing;
- ponding onset;
- runoff threshold crossing;
- short-horizon storage redistribution;
- extreme fluxes.

This is expected to require substantially more vertical information than GW-R.

### SCI-P: profile/process research

Primary information:

- pressure-head and water-content profile;
- local hydraulic gradients;
- internal fluxes;
- regime transitions;
- process attribution.

This is the closest reduced-model purpose to strict Richards fidelity and may eliminate much of the useful reduction.

## Acceptance vector

For a declared purpose P and horizon H, define an output vector

`Y_P(H)`.

The reduced-model departure is not collapsed automatically to a scalar.

For groundwater purposes the minimum vector is:

- `E_Q(H) = |Q_bottom,reduced(H) - Q_bottom,reference(H)|`;
- `E_q(H) = |q_bottom,reduced(H) - q_bottom,reference(H)|`;
- flux-direction agreement outside a separately declared near-zero deadband;
- `E_t = |t_reversal,reduced - t_reversal,reference|`;
- `E_W(H) = |W_reduced(H) - W_reference(H)|`;
- systematic signed exchange bias over long horizons.

For agricultural purposes, analogous components are defined for root-zone storage, actual ET, transpiration, drought timing and capillary supply.

## How a numerical threshold may be sourced

A threshold is admissible only when frozen independently of the candidate result.

Permitted sources are:

1. **Application resolution**
   - the temporal/spatial resolution at which the downstream model or management decision consumes the output.

2. **Downstream sensitivity**
   - propagate the same exchange perturbation into an already-authorized downstream response model and define the maximum tolerable change in the decision variable.

3. **Observation/reference uncertainty**
   - useful as a lower or contextual bound, not automatically as a model-acceptance target.
   - Precision lysimeters can resolve order 0.05-0.1 mm equivalent water over short intervals in high-quality settings, but representativeness and method bias can be much larger.
   - Soil-water measurements likewise have sensor- and soil-dependent uncertainty.

4. **Explicit benchmark model**
   - especially conventional coarse Richards at the same state dimension or computational budget.
   - A reduced model should not be declared useful merely because it is closer to fine Richards than an arbitrary tolerance if an equally cheap coarse-Richards model performs as well or better.

5. **Decision consequence**
   - an error may be acceptable only if it does not change the downstream class, trigger, allocation, irrigation action, drought diagnosis, or other declared decision.

Not permitted:

- selecting a threshold after inspecting the candidate error distribution;
- calling a convenient percentage a hydrological standard;
- reusing the numerical Reference floor as an application acceptance threshold.

## Temporal envelopes

The same reduced state may have different status by horizon.

For example:

- sub-hourly transition fidelity;
- daily exchange fidelity;
- weekly cumulative recharge;
- seasonal water balance.

A representation may therefore be:

`OUTSIDE_DOMAIN_EVT`

while simultaneously:

`ACCEPTABLE_GW_R`

if the fast transient differences decay and do not affect daily or longer groundwater-coupling outputs.

## Reversal timing

Flux sign near zero is numerically and hydrologically delicate.

Therefore reversal evaluation has two layers:

1. exact diagnostic reversal sequence, reported without tolerance;
2. purpose acceptance, evaluated against a separately frozen near-zero deadband and temporal resolution.

A one-step reversal displacement is not automatically a failure of a daily-coupling model, and is not automatically acceptable for an event-scale model.

## Bias versus compensating error

Mean or cumulative agreement is insufficient when positive and negative errors compensate.

RS1 therefore reports at least:

- cumulative signed bias;
- cumulative absolute exchange difference where relevant;
- event-wise direction and timing;
- maxima/extrema;
- horizon-specific storage difference.

This prevents a good seasonal balance from hiding wrong event dynamics.

## Comparator requirement

For every surviving reduced representation, the same purpose envelope is applied to:

1. fine Reference Richards;
2. conventional coarse Richards on the same fixed partition;
3. standard LARE on that partition;
4. EQ-LARE if hydrostatic preservation requires it.

Only then can computational value be claimed.

## Decision vocabulary

A purpose-specific experiment closes as one of:

- `ACCEPT_FOR_PURPOSE`;
- `ACCEPT_WITH_DOMAIN_RESTRICTION`;
- `OUTSIDE_QUALIFIED_DOMAIN`;
- `NO_USEFUL_REDUCTION_AT_THIS_DIMENSION`;
- `COARSE_RICHARDS_SUFFICIENT`;
- `MORE_STATE_INFORMATION_REQUIRED`;
- `REFERENCE_OR_APPLICATION_ENVELOPE_NOT_YET_AUTHORITATIVE`.

No decision implies universal replacement of Richards.

## Current RS1-GW pilot implication

The supplemental two-layer future-probe experiment measured, but did not adjudicate:

- maximum cumulative bottom-exchange difference of about 0.71 mm over 0.8192 day;
- maximum instantaneous terminal bottom-flux difference of about 4.24 mm/day;
- no terminal flux-sign mismatch at the four frozen horizons;
- several reversal-sequence differences of one or two 0.0008-day steps.

These quantities are intentionally not labelled good or bad here.

Their significance depends on whether the target is, for example, daily regional groundwater exchange or sub-hourly transition fidelity.

## Next authority

The formal `LARE-RS1-GW-P2` work unit must:

1. consume the response-blind P1 selected partitions and frozen pair manifests;
2. declare one or more target groundwater purposes;
3. source and freeze the corresponding acceptance envelope before any P2 pair response is executed;
4. execute identical future probes;
5. report each component of the acceptance vector separately;
6. refuse an overall acceptance claim when the application authority needed to set a threshold is absent.
