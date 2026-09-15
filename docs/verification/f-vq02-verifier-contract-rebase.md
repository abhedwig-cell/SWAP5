# F-VQ02 — Verifier contracts rebased on F-CI12

## Scope

F-VQ02 is qualification-only. It rebases previously built VQ reference-seam, canonical-result and transaction/time verifier infrastructure onto the exact qualified F-CI12 basis without changing production source and without claiming new SWAP5 physics qualification.

Exact basis:

- oracle: `B1.10`;
- F-CI11 physical source evidence: `4e8894fc741d7abd711367f712e7aad29d1361eb` plus evidence `b18150cb4f5313f01fc1c775917c617b421c9ba0`;
- F-CI12 qualified source: `7098aeaa4ca38dc375a965340a35c9870a33de28`;
- F-CI12 evidence commit: `729574de00fbb1540affe2af74a7202b38d29754`;
- F-CI12 canonical workflow: `34102787767`;
- historical verifier source: `vq/vq-1e1-transaction-time-harness` at `29e05be97493926ba451dfd53d5ed3170db47ad5`.

## What changed since F-VQ01

F-CI12 closes one blocker from the F-VQ01 inventory: the qualified generic physical interval and unrounded trial-mass seams are now bound into an executable B1.10 reference-model subtype. F-CI12 also qualifies the binding/transaction semantics against a deterministic legacy testdouble.

That does not create an admitted production reference route. F-CI12 explicitly keeps the following unavailable:

- recoverable legacy solver-failure status;
- complete optional-process temporal characterization;
- scalar temporal-error metric and tolerance policy;
- `execute_reference_interval` for B1.10;
- real B1.10 reference-model end-to-end qualification;
- complete snow/macropore storage accounting;
- reentrant parallel legacy-backend qualification.

F-VQ02 therefore treats F-CI12 as qualified production binding evidence with a narrow scope, not as hydrological regression evidence.

## Reused verifier assets

F-VQ02 copies the exact historical Git blobs for:

- reference-seam semantic validation;
- canonical result semantic validation;
- normalized result-record validation and independent unrounded mass residual recomputation;
- TX/TIME verifier harness;
- fault-injection/unit tests;
- associated schemas;
- the stored synthetic harness projection.

Their exact blob identities are recorded in `integration/f-vq/F-VQ02_PROVENANCE.json` and checked by the executable F-VQ02 gate.

The old B1.7-based narrative documents and historical B2 candidate record are deliberately not reused as current qualification evidence.

## Qualification boundary

The verifier contracts describe the acceptance surface a future canonical reference route must satisfy. Passing their unit tests qualifies the validators and synthetic harness only.

The synthetic transaction/time suite still reports:

```text
harness_status                       PASS
b2_physics_status                    NOT_EVALUATED
production_physics_executed          false
production_mass_tolerance_qualified  false
```

F-VQ02 requires those negative statements to remain true. A testdouble PASS is a failure of F-VQ02 if it is relabelled as production physics.

## Current reference readiness

`integration/f-vq/F-VQ02_REFERENCE_READINESS.json` is the current fail-closed readiness record. It acknowledges the F-CI12 generic advance, trial-mass, qualified-profile storage and diagnostics bindings, while keeping canonical reference admission blocked.

No candidate is changed to `READY_FOR_VQ_B1_TO_B2`. No `execute_reference_interval` call is fabricated. No temporal tolerance is invented. No canonical production result is synthesized.

## Executable gate

`tools/vq/fvq02_contract_gate.py` checks:

1. exact F-CI12 source/evidence/workflow provenance;
2. exact historical verifier blob identities;
3. exclusion of stale B1.7 candidate/narrative evidence;
4. F-CI12 admitted and explicitly not-admitted capabilities;
5. fail-closed reference readiness;
6. claim-matrix scope rules;
7. live execution of the 11-case synthetic transaction/time suite;
8. consistency with stored harness evidence;
9. absence of production-source changes relative to the F-CI12 evidence baseline.

The imported seam/result validators and their fault-injection tests run separately in CI.

## Exit decision

F-VQ02 may become qualified when the verifier gate, imported validator tests, TX/TIME harness and exact F-CI12 gate all pass on the persisted F-VQ02 postimage.

That decision is `QUALIFIED_VERIFIER_CONTRACTS_ONLY`. It does not admit canonical reference physics, production warm-start equivalence, temporal equivalence, optional snow/macropore mass accounting or parallel legacy execution.

The next production-facing F-VQ unit must wait for an actually executable canonical reference route. Until then further work remains contract/harness qualification only.
