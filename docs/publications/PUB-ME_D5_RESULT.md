# PUB-ME D5 result

Status: **QUALIFIED_PRIMARY_RESULT_PENDING_POSTIMAGE_ADMISSION**

Publication owner: `PUB-ME`

Experiment family: `D5 — numerical workspace becomes physical authority`

## Design authority

- D1-D6 preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- D5 execution checkpoint: `docs/publications/PUB-ME_D5_EXECUTION_CHECKPOINT.md`
- execution base: `integration/f-ci-canonical@1604b89e6bebf6436dcd2718b8e150bf909d8a01`

The D5 defect family, B1/B2 comparator, selected Reference workspace source, fixture and classification rules were frozen before scientific execution.

## Pre-execution correction

Before the first D5 scientific run, the harness was corrected to respect the already admitted P2E05 residual-unit contract:

- Reference HeadCalc compartment/total convergence residuals retain the existing numeric criterion `1e-12 cm/day`;
- the RossFast integrated mass bound in cm is not used as a Reference convergence criterion;
- the frozen durations are written directly as `0.0016 day` and `0.0008 day`.

This units correction occurred before any D5 result was observed and did not change the D5 defect semantics, fixture or comparator.

The first workflow attempt then failed before compilation/execution because the shell runner referenced a local variable in the same `local` declaration under `set -u`. That runner-only error was corrected without changing the experiment.

## Qualified primary execution

Exact executable head:

- `fff6f7b3db23731c4a9d40c0a10ee6cb8191306d`

Evidence:

- workflow: `PUB-ME D5 workspace authority`
- run: `35288145537`
- job: `105424940164`
- conclusion: **SUCCESS**
- O0: PASS
- O2: PASS
- O0/O2 semantic identity: PASS
- O0/O2 SHA-256: `09b146cd2db3fcce44be4b02348c9de084a9f35c632c19c84799de6651886417`

Documentation on the same executable head also passed in run `35288145574`.

The full canonical qualification run `35288145555` was still in progress when this result record was frozen. The result-bearing head must replay D5, documentation and full canonical qualification before admission.

## Frozen physical fixture

D5 used the prospectively frozen B01 Reference-only fixture:

- 16 cells;
- initial pressure head = -101 cm;
- full Reference solve = 0.0016 day;
- refined comparator = two sequential 0.0008 day solves;
- top prescribed flux = 0.01 times initial conductivity;
- bottom prescribed flux = -0.004 times initial conductivity;
- no roots, drainage, irrigation or macropores.

The full versus refined discrepancy was non-zero as preregistered:

- `U_h_inf = 9.74676858334078133e-6 cm`;
- `U_theta_inf = 1.17382850939318217e-8`.

The fixture therefore did not hit `BLOCKED_FIXTURE_NO_REJECTION`.

## Real Reference workspace source

The preregistered numerical workspace source was:

`full_workspace%richards%old_head`

This field is populated by the real Reference HeadCalc Newton loop from the current nonlinear iterate immediately before a Newton update. It is solver scratch, not committed physical state.

Observed difference from the authoritative committed start:

- head infinity norm = `1.84718366254088551e-2 cm`;
- constitutively recomputed theta infinity norm = `2.22386763967796774e-5`.

The workspace source was therefore informative and D5 did not hit `BLOCKED_WORKSPACE_NOT_INFORMATIVE`.

## Clean retry

The clean 0.0008-day Reference retry started from the original authoritative committed pressure head and water content.

Observed solver status:

- clean retry status = `1` / converged.

## Qualification-only mutant

The mutant promoted the rejected/non-authoritative full-trial Newton `old_head` workspace into the physical pressure-head start state of the 0.0008-day retry.

Water content was recomputed using the unchanged constitutive provider at the workspace-derived heads, so the seeded defect was not an unrelated head/theta inconsistency.

All forcing, parameters, duration, numerical policy and physical equations remained unchanged.

No `src/**` or `reference/**` source was modified.

## B2 transition-authority result

Before the mutant retry solve, B2 compared the proposed physical retry origin with the untouched authoritative physical start state.

Observed:

- workspace-derived pressure head differed from committed pressure head;
- workspace-derived constitutive water content differed from committed water content.

Marker:

`PUB_ME_D5_B2_PRE_RETRY_AUTHORITY_DETECTED=T`

B2 therefore detects the authority violation **before retry execution**.

## B1 strong conventional result

The mutant retry itself converged:

- mutant retry status = `1` / converged.

The strong B1 comparator then detected scientific endpoint differences relative to the clean retry:

- endpoint head infinity norm = `1.84541035659435693e-2 cm`;
- endpoint theta infinity norm = `2.22148296962765279e-5`;
- integrated storage difference = `3.08822652783646845e-6 cm`.

Marker:

`PUB_ME_D5_B1_POST_RETRY_DETECTED=T`

B1 therefore detects the defect after the retry solve through normal scientific endpoint/storage comparison.

## Primary classification

**D5 = EARLIER_DETECTION**

This is exactly one of the preregistered classifications.

D5 is not `UNIQUE_DETECTION`, because a strong B1 comparator detects the scientific consequence after retry execution.

It is not `STRUCTURAL_PREVENTION`, because the public typed solve request is intentionally capable of receiving any physically well-formed start state; the qualification-only mutant can therefore present workspace-derived values as if they were physical input.

The incremental B2 value in this experiment is temporal/localization value: it rejects the wrong state authority before another physical solve is allowed to use it.

## Relation to D1-D4

Current bounded classifications are:

- D1: `STRUCTURAL_PREVENTION`;
- D2: `EARLIER_DETECTION`;
- D3: `STRUCTURAL_PREVENTION`;
- D4: `EARLIER_DETECTION`;
- D5: `EARLIER_DETECTION`.

These are not five independent publication successes.

In particular:

- D1 and D3 both exercise structural state/provenance authority and require final independence analysis;
- D2 concerns accepted accounting contamination;
- D4 concerns restart/persistence contamination;
- D5 concerns misuse of solver scratch as physical retry origin;
- D2, D4 and D5 all currently show earlier rather than unique detection;
- D6 remains unexecuted and may weaken the broad hypothesis;
- physical-regime replication remains an explicit publication obligation.

## Interpretation boundary

D5 establishes only the bounded result above.

D5 does **not** establish:

- an existing SWAP5 production defect;
- novelty of Newton workspace, rollback, retry or solver scratch;
- that conventional scientific regression/testing is inadequate;
- unique detection by B2;
- hydrologic-regime generality;
- publication readiness of PUB-ME.

The current production Reference binding explicitly resets solver workspace and reconstructs physical state separately from `request%base_state`; D5 deliberately seeded a qualification-only modernization error in which that ownership distinction is violated.

## Next permitted action

1. replay D5, documentation and full canonical qualification on this result-bearing head;
2. reconcile any live canonical delta;
3. if all scope-relevant gates remain green and dependencies are stable, admit/close D5;
4. proceed to D6 only as a separate preregistered workunit;
5. after D6, perform a cross-defect independence and publication-go/no-go analysis before elevating RQ1b selective requalification.
