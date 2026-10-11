# F-PE-REPRO02 closeout — difficult-origin exact participant admissibility

Date: 2026-09-26

Status: `CLOSED_TEMPORAL_REJECTION_INITIATES_RETRY_CASCADE`

## Question

Why do the difficult PROFILE06 same-origin mode-5 corrector trials reject tiny nonzero interface-head displacements even though the underlying local q(h) response is smooth and a direct physical Reference solve converges?

## Answer

The initiating rejection is the temporal model-certificate gate, not the nonlinear Richards solver.

For all 12 signed +/-0.001 cm nonzero points:

1. the first full-duration 1e-4 day physical solve converges;
2. mass accounting is not the rejection;
3. the temporal certificate rejects the converged candidate;
4. the generic transaction retry policy halves the attempted duration;
5. after one or more temporal rejections, most cases enter a short-duration nonlinear failure regime;
6. 11/12 nonzero points exhaust the retry budget.

The only nonzero participant PASS, B01-mid +0.001 cm, also begins with temporal rejections, but eventually accepts a reduced-duration transaction and completes the remaining canonical interval.

This corrects the earlier R1 interpretation. R1 observed the final physical attempt after retry exhaustion, which is nonlinear-failed and has no temporal evaluation. That final observation did not establish the first rejection in the transaction sequence.

## Evidence chain

### R1

Established deterministic participant failures and exposed both solver and transaction diagnostics.

Historical interpretation `LOCALIZED_TO_NONLINEAR_SOLVER_BEFORE_TEMPORAL_GATE` is superseded by R13's ordered trace.

### R2-R3

Excluded:

- max nonlinear iteration cap;
- max backtracking cap;
- minimum-step duration

as the initiating explanation.

### R4-R6

Excluded:

- isolated serialized legacy-context binding;
- inactive bottom-flux/top-head carriers;
- optional accepted-direction solve processing.

### R7

Direct and serialized first physical solver requests were identical over the active request/provider surface.

### R8

A preceding predictor-like solve in the same process did not alter corrector convergence.

### R9

Separated physical solve capability from the transaction path:

- bare serialized reference-floor advance: 18/18 PASS;
- normal transaction route: 7/18 PASS.

### R10

Canonical attempt-context capture/restore did not change the failure set.

### R11

Fresh versus retained corrector backend/workspace did not change the failure set.

### R12

Plain physical versus temporal-history state carrier on the same bare serialized physical advance were identical:

- 18/18 PASS in both arms;
- identical nonlinear/backtracking counts;
- identical exchange;
- complete mass accounting.

### R13

Resolved retry ordering.

All 12 nonzero points have first rejection reason TEMPORAL.

No nonzero point has first rejection reason SOLVER or MASS.

Representative full-duration normalized temporal indicators include:

- B01-mid -0.001 cm: about 2.97;
- O14-mid -0.001 cm: about 23.60;
- O14-wet +0.001 cm: about 52.33.

The following reduced-duration retries may still be temporally rejected before entering the nonlinear failure regime.

## Scientific interpretation

The q(h) surrogate hypothesis from APPROX04 was not falsified by local response geometry. It was blocked because the current exact coupling transaction policy does not admit the intended nonzero corrector neighborhood.

REPRO02 now shows why.

The current numerical policy couples:

- a model-certificate temporal indicator;
- a 1e-5 cm temporal budget in the FGC44 fixture;
- retry-scale 0.5;
- same-origin prescribed-head perturbations;
- and a short-duration Reference Richards path that becomes nonlinear-difficult after refinement.

The observed failure is therefore a temporal-policy / retry-path interaction.

REPRO02 does **not** establish that the temporal certificate implementation is defective. It also does not authorize relaxing temporal accuracy. Those questions require a separate policy study with physical error authority.

## Decision

REPRO02 closes diagnostic-only.

No production `src/**` change is admitted.

No APPROX04 surrogate implementation advances.

No direct repair is authorized from this workunit.

## Handoff

Open a separate workunit:

`F-PE-TEMPORAL02 — difficult corrector temporal-certificate / retry-policy frontier`

That workunit should preregister and quantify, at minimum:

- temporal indicator versus refined physical error on difficult same-origin correctors;
- sensitivity to temporal budget;
- accepted substep/retry sequence;
- onset of short-duration nonlinear failure;
- final q/state/mass error;
- runtime;
- whether a coupling-specific but physically qualified temporal policy is justified.

Only after that qualification should any production numerical-policy change or renewed response-surrogate study be considered.
