# F-VQ06 — F-CI18 Exit Scope/Ownership Handoff Qualification

## Decision boundary

F-VQ06 is qualification-only. It changes no production source, physics, solver policy, numerical tolerance or F-CI gate status.

F-CI18 now has qualified scope/ownership evidence: source postimage `a0fdf73b67aa57456d8cbe6700ce707d672981cd`, canonical push workflow `34112588499`, F-CI18 job `101712814659`, full F-CI03-through-F-CI18 dependency chain PASS. Qualification evidence is persisted in commit `2989ff626bef3206119213be7776ed4a11059db6`.

That evidence explicitly precedes gate promotion. `F-CI18_STATUS.json` records `gate_promotion=PENDING_SEPARATE_COMMIT`; `F-CI_EXIT_GATES.json` still contains the F-CI17 assessment with downstream release disabled. F-VQ06 therefore separates two claims:

1. F-CI18 scope/ownership qualification can be independently admitted by F-VQ.
2. Final F-CI exit-gate promotion/downstream release cannot yet be admitted.

## Push qualification versus PR synthetic-merge failures

The authoritative F-CI18 qualification run is the canonical `push` run `34112588499` on exact head `a0fdf73b...`, which completed successfully.

Separate PR-triggered runs failed because default `actions/checkout@v4` checked out a synthetic PR merge and the F-CI18 gate evaluates `git diff --name-only HEAD^ HEAD`. In run `34112593384`, job `101712984493` checked out `bebb886fd215d89234d52b08a95503e45ad972f8`, a merge of the F-CI18 head into the PR base. That context caused existing canonical `src/` files to be reported as if F-CI18 had changed them.

Those PR failures are useful diagnostics but are not authoritative evidence against the exact-source push qualification. Direct source-bound comparison from F-CI17 basis `e17b43e3...` to F-CI18 source `a0fdf73b...` contains no `src/` or corrected-reference source mutation.

## Qualified scope boundary

The F-CI18 ownership interpretation preserves non-delegable source/provenance integrity, transaction correctness and rollback isolation, hard mass conservation for every admitted path, fail-closed handling of unavailable reference/optional-process capability, and one canonical development baseline.

The qualified boundary does not erase downstream evidence requirements:

- F-CI can own B1.10 oracle completeness; production execution of that oracle remains independently qualified downstream.
- F-CI can own persistent-state versus worker-scratch ownership; full backend reentrancy remains separate qualification work.
- F-CI can own the explicit fail-closed temporal-policy contract; F-VQ still owns independent per-metric B1.10 temporal limits.
- F-CI can own generic `[t0,t1]`, canonical result/mass/diagnostic and focused canonical build/regression gates; production reference execution and independent release-level regression remain F-VQ claims.
- No fallback, performance mode or future solver path may weaken hard mass conservation.

## Still blocked

Until F-CI persists its separate gate-status promotion commit, the authoritative exit state remains F-CI17 and `downstream_release_allowed=false`.

F-VQ05 remains unchanged: production temporal limits are unqualified, real B1.10 temporal acceptance is unqualified and production reference execution is `BLOCKED_FAIL_CLOSED`.

A green F-VQ06 gate may therefore qualify only `FCI18_SCOPE_OWNERSHIP_HANDOFF_ONLY`. It must continue to report final exit handoff unqualified, downstream release not admitted and production reference execution fail-closed.
