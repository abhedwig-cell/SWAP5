# DATAQUAL03: bounded perched-exchange numerical policy

Baseline `4b61966e63bcb20d0688c919687a798147226114`. Candidate explicit experimental
numerical policy; no production promotion or historical closure.

The original112-node/five-domain model now completes the previously stalled
2.495→2.514 source window with an optional local perched seepage diagonal
Jacobian. Its physical exchange rates, limiter, equations, tolerances and restart
schema are unchanged. Moving partial-top cells and overlapping limited local
exchange retain the previous derivative. Finite differences through the real
production rate/limiter interfaces pass on GNU13.3 O0/O2, including single-cell
cancellation, multiple cells and malformed-shape rejection.

| Actual calculation | Result | Observed elapsed seconds |
| --- | --- | ---: |
| Historical default production,2days,O2 | physical PASS; predecessor-exact |36.39|
| Historical surface-demand variant,2days,O2,Jacobian off | physical PASS; predecessor-exact |26.22|
| Fresh current-source/policy run0→2.514,O2 | physical PASS; exact split restart |44.28|
| O0 initial0→2.514 attempt | censored60s; day2 checkpoint retained |60|
| O0 own day2→2.514 continuation | physical PASS; exact O2 endpoint/payload |36.18|
| Current-source2.514→2.743,O2 | physical PASS |40.68|
| Current-source2.743→2.748,O2 | physical PASS |11.29|
| Current-source2.743→3,O2 | rejected; last committed2.748 |32.57|
| Same-origin diagnostic2.495→2.514,off/on | off censored60s; on complete |60.01/3.86|

The same-origin diagnostic consumes authentic predecessor state with its original
binding, under the unchanged native physical/schema/CRC checks. It is explicitly
not a new-source restart qualification. No binding or CRC was rewritten. Timings
are observations on this shared machine, not a portable speedup claim. A preceding
20s diagnostic and the first harness assertion failure are retained, not discarded.

The source-bound O2 primary run has an exact full/split state, temperature and
complete restart file. O0 completion uses its own day2 continuation after the60s
censor; endpoint state/temperature and physical restart payload equal O2. Default
and surface-demand-off2day streams and physical restart payload are predecessor
exact on both O0/O2. Joint/rootless numerical heat preservation passes O0/O2.
Six direct native controls reject production/comparison opt-in, unknown policy,
CRC damage, foreign binding and off-policy restart with no output publication.

The next window2.748→3 still fails:102 solver and402 temporal rejections,
25,846 nonlinear iterations,2,460 HeadCalc calls and416 internal accepted
substeps, with minimum timestep8.88e-16day. These internal substeps are rolled
back, not simulated progress. The rejected transaction restart is byte-identical
to an independently completed checkpoint at2.748. There is no mass rejection.
This identifies a remaining transient/temporal convergence problem, not a reason
to remove balance, time-clock or transaction checks. No day3/day5/seasonal success
is claimed. A5day dependency attempt failed before launch; the collector now
reports unavailable predecessor restart as `SKIPPED_DEPENDENCY`.

`summary.csv` retains13 batch executions:7physical completions,3censors,
2rejections/failures (one intentional invalid mode, one old missing dependency),
1dependency skip. Additional actual native checkpoints, diagnostics and controls
are retained separately in the authenticated evidence capsule. These counts are
executions, not13 distinct independent physical configurations. Prior DATAQUAL01
and02 provide45 and20 broader scenario executions; their outcomes are not relabelled.

## Reproduce

Build the native route with `tools/solute/build_project.py --native-water`, using
a current physically compiled provider closure and explicit optimization. Run
`tools/solute/run_dataqual_batch.py --help` for the bundle/config/output arguments;
`integration/dataqual03/scenarios.json` selects the bounded primary runs. The
numerical opt-in is JSON `perched_jacobian: true` or native wrapper
`--perched-jacobian`, with `--mode experimental`. Source-demand mapping is a
separate option. Production remains default.

`STATUS.json` and `RESULT.json` distinguish qualification and pending integration.
`RECOVERY.json` names the actual matched executable, input binding, checkpoint
and next failing command. Decode and verify `evidence-*.b64` using the owning
`integration/audits/verify_dataqual03_current.py` capsule helper; never silently
replace the stored binding. Use a fresh extraction directory for replay.

## Priorities

1. Diagnose temporal estimator/moving perched-boundary behaviour immediately after2.748 using the authentic checkpoint and existing diagnostics.
2. Cover affected valid hydraulic/forcing ranges with short pairwise batches; retain censored work separately from physical progress.
3. Extend completed windows and compare flux/GWL against4.3.1 before making physical-equivalence claims.
4. Address genuinely missing historical process combinations through their owners; retain hard invalid-input and transaction guards.
5. Decide production admission separately after representative numerical evidence; successful experimental execution is insufficient.
