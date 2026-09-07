# F-VQ06 — F-CI18 Exit Scope/Ownership Handoff Readiness

## Decision boundary

F-VQ06 is qualification-only. It does not repair or promote F-CI18 and changes no production source, physics, solver policy, numerical tolerance or F-CI exit-gate contract.

The F-CI18 candidate proposes a scope/ownership interpretation under which all ten canonical-development-baseline exit gates could become qualified while broader production capabilities remain explicit downstream holds. That proposal is reviewable, but proposal metadata is not qualification evidence.

## Observed F-CI18 state

Two source heads have been observed:

- `9d35702452808ff849ae285bca5c4377ea2b87b4` — initial F-CI18 candidate;
- `a0fdf73b67aa57456d8cbe6700ce707d672981cd` — replayability hardening of the F-CI18 gate.

Canonical workflows `34112080253` and `34112593384` are non-green. In the latter run every F-CI03 through F-CI17 job passed and only F-CI18 job `101712984493` failed.

The F-CI18 source/status record still says `PERSISTED_EXIT_SCOPE_CANDIDATE_CI_PENDING`, with both focused gate and canonical CI recorded as `PENDING`. There is therefore no qualified F-CI18 handoff for F-VQ to consume.

## CI-context diagnosis

The F-CI workflow has a `pull_request` trigger and uses default `actions/checkout@v4` behavior. The failing run checked out synthetic PR merge commit `bebb886fd215d89234d52b08a95503e45ad972f8`, described as merging F-CI18 head `a0fdf73b...` into the PR base.

The F-CI18 gate evaluates `git diff --name-only HEAD^ HEAD`. Under that synthetic merge checkout, this is not the F-CI18 source-commit delta; it includes the canonical production line relative to the PR base and therefore reports existing `src/` files as if F-CI18 had changed them. Direct source-bound comparison from F-CI17 basis `e17b43e3...` to F-CI18 candidate `a0fdf73b...` contains no `src/` or corrected-reference source mutation.

F-VQ06 may qualify this diagnosis and the fail-closed admission behavior. It may not convert that diagnosis into a successful F-CI18 qualification. Repairing the F-CI gate belongs to F-CI.

## Ownership proposal review

The candidate preserves the following non-delegable constraints: source/provenance integrity, transaction correctness/rollback isolation, hard mass conservation, fail-closed unavailable reference or optional-process capability, and one canonical baseline.

The proposed division of ownership is acceptable only as a governance boundary, not as a waiver of downstream evidence. In particular:

- F-CI can own the explicit fail-closed temporal-policy contract; F-VQ still owns independent numerical temporal-limit qualification.
- F-CI can own state/scratch ownership boundaries; full legacy-backend reentrancy remains separately unqualified.
- F-CI can own generic `[t0,t1]`, canonical result/mass/diagnostic and focused baseline gates; real production-reference execution and broader regression remain separate F-VQ claims.
- No fallback, performance path or later solver may weaken hard mass conservation.

## Current authoritative exit state

`integration/f-ci/F-CI_EXIT_GATES.json` remains the F-CI17 assessment and has `downstream_release_allowed=false`. That remains authoritative until F-CI itself persists and qualifies a replacement exit-gate postimage.

F-VQ05 also remains unchanged: production temporal limits are unqualified, real B1.10 temporal acceptance is unqualified, and production reference execution is `BLOCKED_FAIL_CLOSED`.

A green F-VQ06 gate therefore qualifies only `FCI18_HANDOFF_READINESS_AND_BLOCKING_ONLY`. It must continue to report `fci18_handoff_qualified=false` and `downstream_release_admitted=false`.
