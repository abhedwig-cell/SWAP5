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



## Oracle evidence search result

Recovered historical oxygen performance evidence does not contain the complete per-call C3Q trace vector. It contains useful aggregate timing, route counts, Newton histograms and output comparisons, but those cannot substitute for physical intermediate parity.

Therefore a minimal diagnostic-only corrected-4.3.1 trace specification is now persisted at:

`tests/physics/PPA_WU05C3Q_ORACLE_TRACE_INSTRUMENTATION.md`

Status: `ORACLE_TRACE_SPEC_READY / ORACLE_VECTOR_EXECUTION_PENDING`.

This is now the narrow execution dependency for the first real A/B comparison.


## Existing Actions/artifact recovery attempt

Repository Actions history available through the connector was searched for prior oxygen/PPA-WU05C/S9/S11 runs. No recoverable matching run/artifact was found in the accessible history.

This route is closed as `NO_RECOVERABLE_ACTIONS_ARTIFACT`; it is not a reason to request another user upload.

## Research-kernel hardening

During pre-execution review, invalid MACRO physical input was found to be represented inside the outer residual as an artificial very-negative value. That could incorrectly classify invalid input as full oxygen stress.

The candidate now propagates invalid residual evaluation explicitly and fails closed. No physical result is returned from an invalid evaluation.


## Authority update: exact B1.5p1 reconstruction

C3Q oracle identity is now pinned to the existing VQ B1.5p1 deterministic reconstruction rather
than to a generic corrected-4.3.1 label.

The B1.5p1 oxygenstress target SHA-256 is
`8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87`.

Existing VQ evidence has already built B1.5p1 with GNU Fortran 14.2 and run the official five-year
grass-growth control to normal completion. Its normalized result_output.csv was byte-identical to
B0 on that control edge.

C3Q therefore does not need to establish source provenance or basic buildability again. It needs
only the new diagnostic physical-response trace and pure-kernel parity.
