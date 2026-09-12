# F-TB09 run log

## Live precondition recheck

Repository: `abhedwig-cell/SWAP5`

Current canonical used as the clean TB09 base:

* branch: `integration/f-ci-canonical`
* commit: `42544af575db522d012db491db801615577048df`
* tree: `4360cd08fd0e952978df9e2742bcc34fdede9ef1`

F-TB01 through F-TB08 were rechecked at their live branch heads. The latest workflow run for each exact head was `completed/success`. Exact immutable heads and run IDs are stored in `F-TB09_WORK_UNIT_CONTRACT.json` and the case manifest.

Canonical moved during the workunit from the initially observed `e537baf...` to the F-CI49 promotion at `42544af...`. TB09 had no commits, so its branch was fast-forwarded cleanly before any materialization. F-CI49 adds qualified restricted solver-service transaction/dynamic-top-boundary infrastructure and a hard mass gate, but does not close the integrated process-interaction gap.

Important ancestry finding: F-TB08 and the current canonical are diverged. Therefore no whole-branch merge/cherry-pick is used. Earlier F-TB contracts are consumed by exact commit authority; TB09 support files are authored cleanly on the current canonical.

## Inventory finding

Permanent/canonical building-block coverage already exists for transaction/restart/MultiSWAP, root uptake, surface evaporation, drainage, variable forcing, WOFOST and restricted soil-temperature runtime. F-TB09 does not duplicate those primitive owner tests.

The missing permanent layer is the explicit interaction catalog: bounded process combinations, a single water ledger across the interaction, transition diagnostics and restart inside an active interaction.

Targeted repository searches for `ponding runoff`, `root uptake evaporation` and `restart mass balance` returned no direct integrated-case hits. This was used only as a duplication check, not as proof that the underlying physics is absent.

## Catalog construction

Eight bounded cases are registered. Selection is risk-based/pairwise, not all-combinations. Every requested physics dimension occurs at least once and the high-risk pairs declared in the manifest are covered.

Every case has stable ID, physics scope, oracle, explicit mass equation, tolerance provenance, execution profile, expected diagnostics, theory/equation references and architecture invariant IDs.

No SWAP4.3.1 corrected golden baseline is created. No O5 legacy case is admitted.

## Qualification boundary

The F-TB09 workflow validates pinned F-TB01..F-TB08 authority, F-TB01 oracle order, mandatory metadata and IDs, hard mass metadata, requested coverage/risk pairs, bounded case size, restart reuse of F-TB04, an O4 Full-Richards reference-oriented DEEP case, and the support-only diff from the canonical base.

It intentionally does not pretend to execute integrated physics cases whose production executor/evidence is not yet pinned. Those remain `CATALOGED_NOT_PHYSICS_QUALIFIED`.

## Source boundary

Production source changes: **none permitted**.

Any source defect exposed later by this catalog must be routed to a separate owner workunit.
