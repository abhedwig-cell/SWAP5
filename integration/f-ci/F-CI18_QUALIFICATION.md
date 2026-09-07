# F-CI18 exit scope and ownership qualification

Status: `QUALIFIED_EXIT_SCOPE_OWNERSHIP_GATE_PROMOTION_PENDING`.

Qualified postimage: `a0fdf73b67aa57456d8cbe6700ce707d672981cd`.
Canonical workflow: `34112588499`, F-CI18 job `101712814659`, PASS on 2026-09-07.
Full canonical dependency chain: F-CI03 through F-CI18 PASS.

F-CI18 changes no production source and does not modify the F-CI15 gate names, required flags or release rule. It qualifies the scope and ownership interpretation needed to distinguish a reliable canonical development baseline from downstream capability completion.

The qualification supports promotion of CI-G02, CI-G04, CI-G05, CI-G06, CI-G07, CI-G08 and CI-G09 to `QUALIFIED`. CI-G01, CI-G03 and CI-G10 were already qualified. The basis is not that the downstream capabilities are complete. The basis is that the F-CI-owned contracts and evidence are complete for a canonical development baseline and unavailable broader capabilities remain explicitly unadmitted or fail-closed.

The scope corrections are:

- CI-G02 qualifies B1.10 corrected-reference completeness as an exact, reconstructible, source-bound oracle. End-to-end execution of that oracle through the new production reference route remains a downstream qualification hold, not a missing part of B1.10 itself.
- CI-G04 qualifies the explicit persistent-state versus worker-scratch ownership boundary. Full backend reentrancy and parallel solver qualification remain downstream work and may not reintroduce solver scratch into persistent column state.
- CI-G05 qualifies the explicit fail-closed reference numerical-policy contract. There are deliberately no invented numeric temporal limits. Independent per-metric B1.10 limits remain F-VQ-owned evidence, and solver-convergence or mass-balance tolerances may not substitute for them.
- CI-G06 qualifies the generic `[t0,t1]` kernel/entrypoint contract. Real B1.10 end-to-end generic reference execution remains unadmitted until its separate numerical and process-scope qualification succeeds.
- CI-G07 qualifies canonical results, unrounded mass accounting and transaction diagnostics for admitted paths. Optional-process paths such as snow/macropores require complete storage accounting before admission. Hard mass conservation is not delegated.
- CI-G08 qualifies executable focused qualification against exact canonical source. Independent F-VQ release qualification remains downstream and must consume the final exact F-CI exit head.
- CI-G09 qualifies the canonical build, focused regression and hard mass-conservation baseline. F-VQ expands independent coverage for subsequently admitted physics and profiles. No fallback, performance mode or future solver path may weaken hard mass conservation.

Non-delegable properties remain provenance integrity, transaction correctness and rollback isolation, hard mass conservation for every admitted path, fail-closed handling of unavailable reference/optional-process capability, and the single canonical development baseline.

This qualification evidence precedes gate promotion. `F-CI_EXIT_GATES.json` remains at the F-CI17 assessment in this evidence commit; downstream release is not enabled until a separate gate-status commit applies the qualified F-CI18 decision.
