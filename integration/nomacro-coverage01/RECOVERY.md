# SWAP5-NOMACRO-COVERAGE01 recovery

Baseline: integration/f-ci-canonical e157e65ff (2026-11-13).
Branch/worktree: codex/nomacro-coverage01 / C:/Users/Veldh012/swap5-nomacro-coverage01.
Frozen RC1: release/swap5-nomacro-rc1-20261112; never modified.
Implementation: experimental process/input route and executable qualification driver persisted; not yet tested.
Test/qualification: not yet run; no new scientific qualification.
Next action: hosted O0/O2 compilation/execution of experimental project selection with exact input inventory,
original process controls, generic grid/calendar metadata and existing daily transactions.
Then compile/run O0/O2 on hosted runner; full original SaltFarm08/16 trajectories,
own restarts, isolation, discard/replay and unchanged three-profile regression.

## Ownership reconciliation

Open PRs checked through GitHub: 1662 (review),1619 (private Andelst),1612,
1485,1465,1457 (older private research); none owns the proposed input route.
STATE02 worktree C:/Users/Veldh012/swap431-state02 at e7c5b44eb;
research/swap431-macro-b1-state02-20261113; no edits to its files or B0/B1.
PERF01 closed by owner on canonical PR1668. Separate unmerged stability branch
codex/rc1-platform-stability01 changes tools/solute/platform* and diagnostic
scripts/workflow; none will be incorporated. Its worktree has only pycache dirt.
Coverage changes will touch daily_host.py, main.f90, daily_coupling.py and
run_water.py after PR1667's publisher changes; the admitted publisher stays intact.
Existing local build belongs to another python process: no heavy local work.
All build/test/output directories belong to this workstream.

## Source-based initial coverage (A integrated; B original present/unconnected;
## C missing/defective integration; D active macro out of scope)

| Process | Status and source/evidence boundary |
| --- | --- |
| Richards/MvG | A for three registered projects; original headcalc/functions retained |
| Hydraulic tables/hysteresis | B functions/hysteresis source; unqualified option/state combinations |
| Top/bottom boundaries | A selected atmospheric, prescribed groundwater, Cauchy, closed bottom; B other boundbottom modes |
| Drainage/surface water | A selected drainage and surface reservoir; B other drainage/divdra/surfacewater options |
| ET/root uptake | A selected Penman-Monteith, Boesten/Black, Feddes/oxygen/salt response; B other original selectors |
| Crops/rotations | A grass/Hupsel rotation/SaltFarm WOFOST; B generic project dispatch; C arbitrary crop-memory combinations not proven |
| Heat | A selected numerical conduction and original storage; B analytical/boundary options; C full mass-carried physical energy |
| Snow/frost | B snow/frozencond source; C complete day-state/process-combination qualification |
| Solute | A conservative CDE/salt selected cases; B adsorption/decay/reservoir/age switches; C matching general ledger/state |
| Irrigation | A selected fixed surface and external surface histories; B original scheduling/subsurface options |
| General project input | B original readswap/TTUTIL available but host enforces case identity; implement first |
| Output/initialization | A selected CSV/native day restart, B generic initial grids/options/output combinations |
| Macropores and macro-only dependencies | D; original research and archives untouched |

A is bounded functional evidence, not whole scientific equivalence. Original oxygen
FAILs, thermal/reference limitations and closed PERF01 scientific limitations remain.
Only three independent no-macro projects exist in the pinned distribution: Hupsel,
Grassgrowth and SaltFarm. SaltFarm workbook runs 2/3 are new configurations of the
same project, not two new independent historical projects. Andelst is excluded.

Invariants affected: 2,3,7,9,11,13,21,23,29: adapter-only input selection,
private original workers, unchanged strict mass/restart/rollback semantics.
No solver or performance campaign; no automatic resumption is configured.


## Executed checkpoints

Hosted run43400125668 at85eb96bea: three-profile regression PASS; SaltFarm08
complete1461, exact365to367 native+auxiliary, isolation and external discard/replay
PASS. Driver stopped on the original SaltFarm S_CONC output-selector defect;
literal refusal retained, output-only comparison preparation added.
Run43401007213 at05df42e90: baseline regression PASS again; SaltFarm08/16
complete1461 each, O0/O2 restarts/isolation/discard/replay and inconsistent-mass
rollback PASS. Hupsel free-bottom refused before first accepted day, with exact
ERROR STOP Unsupported day-budget donor configuration. No convergence failure.
Source hypothesis: the conserved nonmacro substep formula is identical for
explicit prescribed-flux/free-drainage boundaries but was dispatched only for
closed bottom. Extend only explicit modes2/-2/4/7; retain qualified Cauchy branch
unchanged. Reconstructed qbot modes1/5 remain refused for solute profiles.
This is the first targeted functional repair; no solver/tolerance change.
