# Basic original option block

Workstream SWAP5-NOMACRO-COVERAGE01. Branch codex/nomacro-coverage03,
following blockB12ae91148 and admitted blockA980273f81. Same private worktree;
new dedicated hosted workflow/output. No peer source or release branch changes.

Implemented, not yet tested/admitted: original no-heat switch, original bare-soil
configuration, undrained/free-bottom combination, original prescribed-flux table,
sinusoidal bottom and q(h) bottom options. Original bodies are already linked;
no Fortran physical-law, solver, tolerance or state-codec change in this block.
Strict solute candidate balance already covers explicit bottom modes2/-2/4/6/7.
No-heat retains original default soil temperature and cannot combine with snow.

Six derived Hupsel configurations. Table-flux test explicitly replaces the dormant
2002-only source table by three downward-flux knots covering2002through2004;
sine uses original function with explicit mean-0.05/amplitude0.02cm/day. These
are recorded derived physical inputs, not original historical-project variants.
Other process parameters and original meteorology remain unchanged.

Next: persist/push, actual O0/O2 whole-period/water/solute/restart/isolation/
discard/replay/refusal comparisons. No scientific or full-equivalence claim.
