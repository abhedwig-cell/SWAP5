# F-PE-TEMPORAL02 — difficult corrector temporal-certificate / retry-policy frontier

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent:
`F-PE-REPRO02`

Parent authority:
`b55970dc949ea58ba19494e28f862cd62b1dcfe4`

## Trigger

REPRO02 establishes the ordered failure chain for difficult same-origin mode-5 correctors:

1. the full 1e-4 day physical Reference solve converges;
2. mass acceptance is not the first rejection;
3. the temporal model certificate rejects all 12 tested +/-0.001 cm nonzero points;
4. the generic retry policy halves the attempted duration;
5. 11/12 points subsequently enter a short-duration nonlinear failure regime and exhaust retries.

The exact local q(h) response is smooth over much larger head windows. The collapsed participant frontier is therefore a temporal-policy / retry-path interaction, not a local constitutive-response discontinuity.

## Purpose

Map the physically meaningful frontier between temporal-certificate strictness, transaction completion, physical error and runtime for difficult same-origin correctors.

This workunit is research-only.

Do not change production `src/**` in the characterization phases.

Do not infer that a looser temporal budget is acceptable merely because it completes.

## Primary questions

1. How conservative is the current 1e-5 cm temporal head budget relative to refined physical error?
2. At what budget does the full-duration converged candidate become admissible?
3. How do budget, retry count, accepted substeps and nonlinear effort interact?
4. Does relaxing only the temporal budget avoid the short-duration nonlinear-collapse regime?
5. What final state, q, mass and trajectory error is introduced relative to a refined exact Reference oracle?

## P0 — budget frontier

Use the six difficult PROFILE06 origins:

- B01 wet;
- B01 mid;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid.

Use signed corrector offsets:

- -0.001 cm;
- +0.001 cm.

Keep fixed:

- exact Reference solver;
- mode 5 prescribed head;
- 48 max nonlinear iterations;
- 16 max backtracking;
- min step 1e-10 day;
- retry scale 0.5;
- max retries 8;
- mass/head tolerances 1e-12;
- same committed origin and predictor authority.

Sweep temporal head budget:

- 1e-5 cm, current fixture authority;
- 2e-5 cm;
- 5e-5 cm;
- 1e-4 cm;
- 2e-4 cm;
- 5e-4 cm;
- 1e-3 cm.

For every point record:

- participant status;
- transaction attempts/retries;
- solver and temporal rejections;
- accepted substeps;
- min/max accepted substep duration;
- max normalized temporal indicator;
- total nonlinear iterations and backtracking;
- final q and accepted state where available;
- wall-clock time for a repeated timing arm after functional characterization.

## Refined physical oracle

Budget acceptance is not the physical-error authority.

For each case/offset, construct an independent refined Reference oracle using physically successful fixed substeps that span the same 1e-4 day requested interval without using the candidate budget under test as the acceptance criterion.

Report at minimum:

- terminal pressure-head max norm;
- terminal water-content max norm;
- bottom exchange difference;
- terminal bottom-flux difference;
- mass residual.

The oracle definition must be frozen before using it to admit any candidate policy.

## P0 interpretation

P0 is descriptive.

Advance only if at least one budget above 1e-5:

- materially increases successful nonzero completion;
- avoids or reduces the temporal-to-nonlinear retry cascade;
- retains finite and conservative mass accounting.

No production recommendation follows from completion alone.

## P1

If P0 finds a nontrivial completion frontier, preregister physical-error qualification against the refined oracle.

Candidate budgets must be evaluated on hydrological error and runtime together.

## Stop conditions

Stop or split to a repair workunit if:

- temporal indicator behavior is internally inconsistent with its documented quantity;
- loosening the budget exposes a production defect rather than a policy tradeoff;
- mass accounting becomes incomplete or nonconservative;
- the refined oracle cannot be defined independently of the tested policy.

## Scope boundary

Not admitted here:

- response surrogate;
- altered production defaults;
- new retry algorithm;
- changed Richards equations;
- solver repair;
- default-on approximation.

Any production change requires a separate qualification/admission workunit.
