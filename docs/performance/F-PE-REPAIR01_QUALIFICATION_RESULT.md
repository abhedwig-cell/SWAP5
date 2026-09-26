# F-PE-REPAIR01 qualification result

Date: 2026-09-26

Status: `QUALIFIED`

## Production repair

The production change is intentionally minimal.

In:

`src/adapter/mod_reference_richards_legacy_binding.f90`

mode-5 bottom-flux materialization now uses:

- the authoritative root-sink provider scratch only when
  `request%evaluation%root_sink` is associated;
- exactly zero root extraction contribution when no root-sink provider is present.

No workspace-wide reset was added.

No solver tolerance, timestep rule, constitutive relation, coupling policy or transaction rule was changed.

## Q1 — inactive-root poison regression

The REPRO01 provider-singleton poison matrix was rerun against the repaired production source.

Result:

- ZERO: 40/40 PASS;
- THETA: 40/40 PASS;
- K: 40/40 PASS;
- CAPACITY: 40/40 PASS;
- DKDH: 40/40 PASS;
- ROOT_SINK: 40/40 PASS.

Before the repair, ROOT_SINK was 0/40 PASS with the characteristic status-6 failure.

This is the direct regression gate for the repaired ownership defect.

## Q2 — exact first-corrector repeatability

Exact/default reduced first-corrector probe:

- 40/40 PASS;
- 0 status-6 failures.

The successful solver path retains the expected converged first-corrector signature.

## Q3 — fixed-build live repeatability

One exact binary and one A2C binary were compiled once and each executed in 20 fresh live SWAP + MODFLOW6 processes.

After the repair:

- exact: 20/20 PASS;
- A2C: 20/20 PASS.

Before the repair, the same fixed-build experiment produced:

- exact: 12/20 PASS;
- A2C: 16/20 PASS.

The previously observed process-to-process status-6 nondeterminism is therefore eliminated in this qualification fixture.

## Q4 — A1 and A2C live controls

A1 live control:

- PASS;
- final head identical to exact;
- final SWAP exchange identical;
- ledger exchange identical;
- coupled iterations identical;
- one fresh tangent and three reuses;
- measured speedup in this short replica: about 5.36%.

A2C live SWAP + MODFLOW6:

- 6/6 independent replicas PASS;
- all six retain exact final head, SWAP exchange, ledger exchange and iteration count;
- no candidate-only status-6 failure.

Observed coupled-loop speedups were approximately:

- 13.91%;
- 0.87%;
- 0.99%;
- 1.16%;
- 3.01%;
- 1.34%.

These sub-millisecond timings are retained as observation only; the robustness and endpoint results are the qualification authority.

## Q5 — application-shaped A2C preservation

The existing APPROX02 application sequence passed.

Current-postimage observation:

- measured speedup about 28.81%;
- exact nonlinear iterations: 60;
- A2C nonlinear iterations: 60;
- accepted substeps: 20 versus 20;
- retries: 0 versus 0;
- maximum mass residual: 0;
- cumulative net-flow difference: 0;
- cumulative storage difference: 0;
- maximum storage-end difference: 0.

## Q6 — root-active semantic preservation

Paired test-only builds compared:

- repaired conditional qrosum logic;
- old-equivalent unconditional qrosum logic.

Both used:

- `root_extraction_active=.true.`;
- identical nonzero prescribed root-extraction sink.

Result:

- repaired: 20/20 PASS;
- old-equivalent: 20/20 PASS;
- paired output parity: PASS.

Therefore the repair does not alter the root-active meaning. It only removes the invalid read from the root-inactive route.

## Broader CI context

The REPAIR01-specific workflow is fully green.

Also green on the same head:

- documentation;
- F-CI110 reconstructed performance admission;
- ZERO-WASTE01 poisoned workspace;
- ZERO-WASTE01 paired runtime;
- F-PERF-CANON01 B1 recomposition;
- F-PERF-CANON01 D AHL50.

Several unrelated repository-wide preservation/publication gates remain red.

PR #637 changes only:

- `.github/workflows/f-pe-repair01.yml`;
- REPAIR01 documentation;
- `src/adapter/mod_reference_richards_legacy_binding.f90`;
- `tests/fpe/run_fpe_repair01_root_active_parity.sh`.

Examples of red-gate causes are inherited preservation expectations for other source owners, including transaction/RossFast surfaces, and an unrelated publication pilot compile dependency.

Those failures are not evidence against this repair and are not modified in REPAIR01.

## Decision

F-PE-REPAIR01 is technically qualified.

The exact mode-5 inactive-root read-before-write defect is repaired with the minimal ownership-correct change, while root-active behavior and previously retained A1/A2C behavior are preserved.
