# PPA-WU05-C3Q — Bartholomeus physical-response qualification

Date: 2026-10-01

Status: `PREREGISTERED / EXECUTION_PENDING`

Parent research: PPA-WU05-C3R

## Claim under test

For `SWOXYGEN=2, SWOXYGENTYPE=1` with analytical MvG hydraulics, the reconstructed pure Bartholomeus kernel reproduces the corrected SWAP 4.3.1 physical oxygen response while eliminating persistent oxygen runtime state and restart-based Newton policy.

## Oracle

Corrected SWAP 4.3.1 B1.11 behavior, including SWAP-007 guard.

The public legacy SWAP source is reconstruction evidence only. It is not the qualification oracle.

## Trace vector

Every paired evaluation must capture:

1. water-film thickness;
2. soil oxygen diffusivity;
3. microbial respiration at z0;
4. c_macro;
5. c_min_micro;
6. respiration factor;
7. final root-water-uptake factor.

Final-output equality alone is insufficient because compensating MICRO/MACRO differences could otherwise be hidden.

## Scenario envelope

Required:
- no-stress endpoint;
- interior oxygen limitation;
- near-full stress;
- saturated/gas-porosity shortcut;
- max_resp_factor == 1 special case;
- cold and warm soil;
- low/high organic matter;
- shallow/deep rooted node;
- dry water-film shortcut;
- SWAP-007 tiny-derivative historical failure class;
- at least one official/retained grass oxygen case with many calls.

## Numerical comparison

The physical-response comparison will distinguish:
- exact-preserving algebra;
- solver-policy differences;
- water-film quadrature differences.

The initial gate records absolute and relative differences rather than choosing a tolerance after seeing results.

Admission tolerance must be preregistered after numerical scale characterization and before the held-out cases are evaluated.

## Required A/B structure

A: corrected 4.3.1 trace
B: reconstructed pure-kernel trace
A replay: corrected 4.3.1 trace

A/B/A is required for real-case extraction to exclude hidden run-order or mutable-cache contamination.

## Failure classification

Any mismatch must be assigned to one of:
- source-version formula difference;
- unit/parameter mapping error;
- water-film quadrature policy;
- outer solve policy;
- inner MACRO solve policy;
- invalid/uncovered physical domain;
- oracle instability/non-determinism.

No tolerance widening is allowed as a substitute for classification.

## Production gate

C3Q can qualify a production-admission candidate only if:
- all physical trace fields are accounted for;
- no true cross-timestep oxygen state is discovered;
- water sink ownership remains external;
- SWAP-007 class is absent or explicitly guarded;
- standard non-oxygen routes are unaffected.

