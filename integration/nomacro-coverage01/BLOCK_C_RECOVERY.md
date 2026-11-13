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

First C run43405930779 at6540727fe: bare soil completes1096 with all O0/O2,
restart/isolation/rollback/external controls. No-heat original rotation executes
523days then original read_stressors refuses future potato SWOXYGEN2 because
physical oxygen requires SWHEA1/SWCALT2. This is an invalid input combination,
not a solver failure. New preflight enforces that original rule for every crop
before build/output, including crops that start in a later year. Its actual CLI
refusal is tested. Positive no-heat fixture uses bare soil/free bottom, with no
physical oxygen process. The invalid original attempt and its523-day prefix
remain preserved in source-bound run43405930779 and local verified artifact.

Source9e8e86ee1, run43407021524: all6 complete1096 trajectories and O0/O2/
restart/isolation/rollback/external controls PASS. Follow-up adds the cultivated
no-heat/Feddes maize rotation (all3 original date windows use the original maize
file/simple growth). Process preflight now validates actual referenced future
crop files, retaining unused files in the exact inventory without letting them
activate physical options. Seven derived cases; no new crop/soil/heat law.

Peer reconciliation2026-11-13: platform branch e4767ec95 adds explicit FP flags
and matching provider/build identity in daily_host/daily_coupling/user_prepare/
b0_source_runner. Those hunks are distinct from coverage's experimental project
lookup and option-active restart carry. They are NOT imported. Performance owner
retains compile policy; future canonical admission of that profile invalidates
relevant source/build qualifications and needs its own remeasurement. No overlap
with blockC's experimental_project/test/workflow changes. Macro STATE02 now has
uncommitted research/swap431-macro-b1-unreduced04 files atf62e19e2c; untouched.

Final source24a5ed08c: run43408409505 SUCCESS, all7 complete1096 trajectories
(7672days),14 O0/O2/native own controls, independence/rollback/external controls
and17 logical/physical input refusals pass. BLOCK_C_STATUS.json owns scope,
actual unchanged compiled-source dependency comparison to PR1670 and peer overlap.
