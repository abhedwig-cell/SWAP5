# KALM-S431-01: execution boundary and recovery, 2026-10-18

## Verified repository state
- Research branch: research/kalmthout-sw5-state-export-20261018
- Full accepted state export in research/kalmthout_pilot/kalmthout_swap5_pilot.f90, commit d903e1873d6eeb300a05ee450dc8252d80011b5e.
- Parser, five parser regression cases, and narrow 1700-hour workflow are committed.
- Last targeted trigger: 28e7920675bf724605b43811204597ca94b15f53.
- Wrapper was fixed for an intentionally nonzero solver exit and Actions detached checkout in commits cfb7810b and 1812c19b.
- The available GitHub connector exposes no list-workflow-runs or workflow-dispatch action, and its commit-workflow-runs endpoint is restricted to PR-triggered runs. An empty result there DOES NOT establish that the push workflow failed to start.
- Local git access fails DNS resolution of github.com. Do not trigger repeatedly or claim execution.
- The new research workflow may also be unregistered in the default branch; without a true workflow-list or run-list endpoint, this remains unverified, not an established root cause.

## Reproduction
1. On the GitHub Actions UI inspect `kalmthout-accepted-state-export.yml` on the research branch or its branch-associated run.
2. If a completed run exists, obtain `kalmthout-full-state-export` from it. Check `run.log`, `dry_diagnostic.log`, and `STATE_DUMP_COMPLETE=PASS`.
3. If none exists, run the bounded command in a checkout: `bash research/kalmthout_pilot/run_state_export_diagnostic.sh /tmp/kalmthout-state`; alternatively register/dispatch the isolated workflow via a supported runner.
4. Once a complete vector exists, compare its timestamp, depths, heads, theta and ponding to the independent SWAP4 grid; only then build an exact replay. Do not equate a top-only trace with full state.

## Qualified claims
- SWAP4.3.1 independent Kalmthout real-weather test: historical interval computed (with experimental, not observed site soil).
- SWAP5 full atmosphere: blocked at 2024-03-09T13:00.
- Exact SWAP4/SWAP5 matched-state replay and production Jacobian finite differences: NOT RUN.
- No canonical modification, no justified numerical parameter or hard mass gate relaxation.
