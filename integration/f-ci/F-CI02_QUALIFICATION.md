# F-CI02 qualification record

## Scope

F-CI02 establishes the canonical integration root only. No production kernel, solver physics, numerical policy, transactional implementation, runtime or MultiSWAP source is changed.

## Materialized artifacts

- canonical branch: `integration/f-ci-canonical`
- machine-readable source/provenance manifest: `integration/f-ci/canonical-source-manifest.json`
- fail-closed focused gate: `tools/fci/fci02_reference_root_gate.py`
- decision record: `docs/integration/F-CI02_CANONICAL_REFERENCE_ROOT.md`
- reproducible gate commands: `integration/f-ci/F-CI02_GATE_COMMANDS.md`
- status record: `integration/f-ci/F-CI02_STATUS.json`

## Canonical pins

- repository/main root: `fafeebdece209abcc320b24a3c8c2757800b2e0e`
- corrected legacy oracle: B1.10
- B1.10 admission: `5a25526e77a4e1ba3b8f2755cb1e59ca0700ee96`
- B1.10 source-manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`
- transactional forward-port candidate: `763f276a96ee1722a465bacd3a710172a5f38107`
- A23/B1.10 merge base: `2d05eeab9d766d51bc7c436ea1e45f9b49940e92` (B1.6)

## Qualification state

`MATERIALIZED_GATE_PENDING_EXECUTION`

This is deliberate. Git provenance and the focused gate are materialized, but a full PASS is not claimed until the existing B1.10 reconstruction/admission gate has executed successfully in a suitable checkout/runtime containing the required corrected-reference inputs.

F-CI03 production-source changes are therefore held until that full F-CI02 gate passes.

## Invariant review

F-CI02 is consistent with the core invariants because it introduces no kernel I/O, no physics changes, no performance policy, no state-layout change and no transaction semantics change. It explicitly preserves B1.10 as oracle, prohibits direct merge of the B1.6-based A23 line, carries generic `[t0,t1]` and hard mass conservation forward as unresolved production requirements, and records worker-owned scratch/reporting-state holds before the forward-port starts.
