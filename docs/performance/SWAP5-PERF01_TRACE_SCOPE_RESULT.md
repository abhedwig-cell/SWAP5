# PERF01 rejected-branch trace storage

The private Reference backend now releases flux payloads belonging only to
abandoned trial branches after the enclosing transaction's private contexts
expire. All entries predating the scope remain pinned. Surviving new payloads
move without changing their values; only private arena indices are remapped.
The original transaction algorithm body is byte-identical after its routine
name is normalized. Existing execution arguments, equations, tolerances,
retry order, acceptance decisions and physical restart formats are unchanged.

## Measured dry32 resource control

Fresh baseline: `969aa918f0104546ec4ca2372feccf37b0145627`.
All processes request the same six reporting windows. GNU Fortran13.3 O2 uses
the existing production profile; O0 uses the checked profile. Each process has
a 90 s timeout. Peak RSS comes from that process's `wait4` receipt, not a shared
parent high-water mark.

| Execution | Address-space limit | Peak RSS (KiB) | Outcome |
| --- | ---: | ---: | --- |
| Baseline O2 | 1536 MiB | 961660 | Original numerical exhaustion |
| Baseline O2 | 512 MiB | 520836 | SIGSEGV/ENOMEM; incomplete resource control |
| Scoped O2 | 512 MiB | 74968 | Exact original numerical exhaustion |
| Scoped O0 | 512 MiB | 77196 | Exact original numerical exhaustion |

The paired O2 observations reduce peak RSS by 92.2% (12.83 times). One timing
observation is insufficient for a speedup claim; the scoped O2 probe was
slightly slower. The baseline 512 MiB failure is retained as a failed resource
control, never a scientific PASS.

The three numerically completed probes have byte-identical `budget.csv`,
`trajectory.csv` and failure stdout, and identical deterministic work counters.
All reject requested window 6, `[0.078125,0.09375]` day. Both externally committed
clocks stay at 0.078125 day; no chemical substep is published. The numerical
rounding problem remains open. No one-ULP correction is included here.

## Selected preservation

Three fresh 187-provider column builds cover baseline O2 and scoped O0/O2.
Six direct policy/proposal/lifecycle runs include seven transaction return
routes. Twelve real private-arena runs cover immutable branches, nested and
empty scopes, pinned siblings, suffix compaction and expected stale/invalid
context rejections. Two further O0/O2 runs exercise repeated movement of deep
salt receipts, rank-two drainage and allocated zero-extent macropore arrays.

The original 86 file-application assertions pass. Eight incumbent runtime outputs
remain exact. Original matrix and pond thermal validators assess six exponents
each, with fresh O0/O2 physical execution, complete refinement grids, rollback,
fresh-process restart, semantic rejection and crash recovery. Original month
and year application assertions preserve all 160 prior application artifacts.
Annual mass-grid differences remain measured spread, without a monotonicity
claim. No full migration or master-coverage promotion follows from this work.

Concurrent finite-donor canonical work at
`c4ec414fe5ae55e992e557e394cb4003beaf3e39` changes none of those executed source
footprints. Its original production and retained joint callers are separately
selected for fresh shared-runtime preservation. Admission uses an exact frozen
canonical predecessor, exact additive owner handoffs and a closed source delta.
The machine-readable status and source-bound verifier hold completion receipts.

The capsule includes failed setup observations: a missing `/usr/bin/time`
preflight (replaced with `wait4`), an overly specific malloc-message assertion
(corrected by revalidating unchanged raw observations), and the first concurrent
NUT preflight lacking `gfortran` on PATH. A second NUT attempt stops with SIGSEGV
at the original driver's entry under the shell's 8 MiB stack. The same checked
executable passes with unlimited stack; the final original caller runs explicitly
inherit that setting. These failed observations are not scientific passes.

Scope cleanup bounds abandoned new payloads across transactions. It does not
collect arbitrary externally retained history or guarantee constant memory with
simulation length. The balanced, same-owner scope lifetime contract remains
binding; generation and watermark checks reject detectable invalid tokens.
