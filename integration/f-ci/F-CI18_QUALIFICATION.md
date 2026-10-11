# F-CI18 exit scope and ownership qualification

Status: `QUALIFIED_EXIT`.

## Exact qualified lineage

- Qualified scope postimage: `a0fdf73b67aa57456d8cbe6700ce707d672981cd`.
- Scope qualification workflow: `34112588499`, F-CI18 job `101712814659`, PASS.
- Scope qualification evidence commit: `2989ff626bef3206119213be7776ed4a11059db6`.
- Evidence-commit canonical replay: `34112977416`, PASS.
- Formal gate-promotion / canonical-development-baseline exit head: `1eceed967b12396b8bbc832f897376378463adce`.
- Gate-promotion canonical replay: `34114164800`, F-CI18 job `101717589931`, PASS.
- Full dependency chain on the promotion postimage: F-CI03 through F-CI18 PASS.
- Qualified production source head remains `da5026d8b87ad2f3c7912360891839a120ecccb6`; F-CI18 changed no production source.
- Corrected legacy oracle remains B1.10.

## Exit decision

All required CI-G01 through CI-G10 are `QUALIFIED` in `F-CI_EXIT_GATES.json` and in the immutable `F-CI18_EXIT_GATES.json` snapshot. `downstream_release_allowed=true`.

F-CI18 did not change the F-CI15 gate names, required flags or release rule. It qualified the scope and ownership interpretation needed to distinguish a reliable `CANONICAL_DEVELOPMENT_BASELINE` from downstream capability completion.

The promotions do not claim that downstream capabilities are complete. They establish that the F-CI-owned contracts and evidence are complete for the canonical development baseline and that unavailable broader capabilities remain explicitly unadmitted or fail-closed.

The qualified scope corrections are:

- CI-G02: B1.10 corrected-reference completeness is the exact, reconstructible, source-bound oracle. End-to-end execution through the new production reference route remains downstream qualification work.
- CI-G04: the persistent-state versus worker-scratch ownership boundary is qualified. Full backend reentrancy and parallel solver qualification remain downstream and may not reintroduce solver scratch into persistent column state.
- CI-G05: the explicit fail-closed reference numerical-policy contract is qualified. There are deliberately no invented temporal limits. Independent per-metric B1.10 limits remain F-VQ-owned evidence, and solver-convergence or mass-balance tolerances may not substitute for them.
- CI-G06: the generic `[t0,t1]` kernel/entrypoint contract is qualified. Real B1.10 end-to-end generic reference execution remains unadmitted until its separate numerical and active-process qualification succeeds.
- CI-G07: canonical results, unrounded mass accounting and transaction diagnostics are qualified for admitted paths. Optional-process paths require complete storage accounting before admission. Hard mass conservation is not delegated.
- CI-G08: executable focused qualification against exact canonical source is qualified. Independent F-VQ release qualification remains downstream and must consume the exact F-CI exit head.
- CI-G09: the canonical build, focused regression and hard mass-conservation baseline is qualified. Independent VQ expands coverage for subsequently admitted physics and profiles; no future solver, fallback or performance path may weaken hard mass conservation.

Non-delegable properties remain provenance integrity, transaction correctness and rollback isolation, hard mass conservation for every admitted path, fail-closed handling of unavailable reference/optional-process capability, and the single canonical development baseline.

## Downstream boundary

F-CI has no remaining exit blocker. Downstream workstreams may use `1eceed967b12396b8bbc832f897376378463adce` as the qualified canonical-development-baseline exit head. This does not itself mark F-KT, F-SI or any other downstream workstream as released; their own governance still decides release. F-VQ should source-bind future release-level claims to this exact exit lineage.
