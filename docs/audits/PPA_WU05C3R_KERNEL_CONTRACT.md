# PPA-WU05-C3R kernel contract candidate

Status: RESEARCH CONTRACT, NOT PRODUCTION ADMISSION

## Purpose

Define the smallest SWAP5-facing contract supported by recovered Bartholomeus/SWAP 4.3.1 evidence before implementing the standalone reference kernel.

## Data classes

### Immutable physical/configuration input

Crop/root oxygen configuration:
- maximum respiration factor;
- root respiration parameters and temperature response;
- microbial respiration parameters and temperature response;
- senescence/root geometry terms required by the legacy MACRO/MICRO equations;
- atmospheric/top oxygen boundary terms required by the source equation.

Soil/node construction data:
- hydraulic parameters required for water-film geometry;
- gas-diffusivity construction coefficients;
- node/layer geometry.

### Shared immutable derived data

Recovered and already classified:
- d_soil_term1;
- d_soil_term2;
- gfp100;
- capac_term;
- nmin1;
- mplus1.

These are not transactional column state.

### Current evaluation input

Per node/call:
- current water content / gas-filled porosity;
- current matric potential;
- current soil temperature;
- node depth / geometry;
- current root/crop demand terms.

### Call-local numerical scratch

- water-film thickness;
- current soil oxygen diffusivity;
- macro oxygen concentration;
- minimum micro/root oxygen concentration;
- bracket endpoint residuals;
- scalar root variable / respiration factor;
- solver iteration counters/status.

No recovered evidence currently justifies persistence of any of these across accepted timesteps.

## Response

The physical kernel returns an oxygen/root-water-uptake reduction factor, bounded by the legacy physical response envelope. It does not own or book water mass.

## Reference execution policy

1. Evaluate current gas diffusivity from current gas-filled porosity plus immutable precompute.
2. Evaluate water-film geometry once.
3. Evaluate the residual at maximum respiration/demand.
4. If oxygen supply is sufficient there, return the exact no-stress result immediately.
5. Otherwise establish the legacy bracket over [0,max_resp_factor].
6. Solve the instantaneous scalar balance with a robust bounded method.
7. Preserve corrected-reference SWAP-007 representability semantics for any Newton-compatible oracle path.

The production SWAP5 implementation is not required to reproduce legacy Newton iteration history. It is required to reproduce the qualified physical response within the declared reference tolerance and preserve all owner/mass contracts.

## Numerical routes

REFERENCE:
- source-equivalent water-film evaluation;
- robust bounded scalar solve;
- no approximation tables.

PRACTICAL candidate:
- WFT300 or successor lookup;
- only after separate approximation qualification;
- reference route retained as oracle/fallback.

## Falsification criteria

This contract is false if exact source reconstruction demonstrates any of:
- a physically meaningful oxygen variable carried from one timestep to the next;
- dependence on rejected-trial history;
- a source-required solver state that changes later physical response at identical current inputs;
- non-bracketable/multi-valued response over the valid physical domain that invalidates the bounded scalar formulation.
