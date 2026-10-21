# MC-SOL01 native SWP water bootstrap

Canonically admitted bounded route through PR1362 and PR1363. Baseline48a59396d7e7745cf99ad4b1003cd84c946e3e3f.

An explicit `swp_water_bootstrap=.true.` in the column namelist selects original
TTUTIL input for ISUBLAY/ISOILLAY/HSUBLAY/NCOMP, default unimodal MvG layer
parameters, and unsaturated HTB initial pressure heads. Schema2 with nodes=0 and
zero explicit cell thickness is required. Explicit pressure-head and hydraulic
scalar overrides are rejected. Original soil-layer indices map parameters to
every cell; chemistry is then imported through the existing original reader on
the same grid. Neither kernel equations nor solver/runtime/restart formats change.

Source authority is archived B1.11 readswap.f90 (soil input and paramvg assembly)
and soilwater.f90 task1 (original AFGEN_2 on absolute node depth). This is a new
bounded adapter using original TTUTIL and original AFGEN_2/RDADORTB; it is not
execution of the entire historical readswap procedure. KSATFIT falls back to KSAT
as in the source. Non-increasing HTB depth, saturated initial profiles, SWINCO2/3,
hysteresis, hydraulic models other than1, tables/database, KSATEXM, power tails
and elastic input fail before physical owners exist. The current application's
narrower parameter ranges remain in force. Legacy deprecated ZI/H is excluded.

The namelist still owns initial pond and surface chemistry, surface and bottom
forcing, explicit root and drain sinks, heat and numerical policy. No historical
pond initialization, groundwater reconstruction, meteorology, crop evolution,
drainage/bottom orchestration or standard-output equivalence is claimed. All
existing chemistry exclusions remain. Full historical migration stays open.

Affected invariants:2,3,7,13,21,23,25,27,29. Required evidence is actual O0/O2 native
layer/grid/head mapping; independent initial water/chemical inventory; production
joint balances and exact independent-process restart; atomic invalid-input and
changed-SWP rejection; original file and chemistry regression. Source/evidence
validation must bind the adapter and every real build input. Full F-CI and highest
low-air are not selected for adapter-only changes to an opt-in application.

Example, after building tools/solute/build_column.py:

    python tools/solute/run_column.py --exe BUILD/swap5_solute_column --input examples/solute_column/swp_water.nml --swp examples/solute_column/layered_water.swp --output RESULT

The existing launcher already hashes and publishes both exact input files, so
bootstrap selection and every water parameter remain bound to the complete
restart generation. A restart with changed input/SWP/executable is rejected.

## Local result, 21 October 2026

GNU13.3 checked O0/O2 builds use190 real application providers plus original
TTUTIL. The independent input driver links only three existing application/input
providers plus TTUTIL. Twelve native mapping cases and twelve exact fresh-process
continuations pass, including reversed soil-layer indices, KSAT fallback and
scalar/array/default hydraulic model selection. Sixty invalid/conflicting-input
observations reject without final generation publication. Independent initial
MvG water and original layered Freundlich inventory checks pass. Maximum native
water/solute residuals are4.508112633194727e-16cm and1.7539366226754227e-13mg/cm2.

All172 original SWP chemistry observations and86 original file-application
observations pass on these exact executables. Fresh baseline O0/O2 application
builds compare152 completed valid output/restart files byte-for-byte. Interrupted
random staging directories and intentionally corrupted generations are excluded
from that byte count; their original crash/corruption assertions still execute.
The existing qualified production providers remain exact. Five concurrently
admitted NUT output adapters outside the190-provider closure are preserved.

The existing MC_SOL01_DYNAMIC_DECAY_STATUS.json#swp_water_successor owns the
7049-member immutable evidence capsule, source-bound validator, actual costs and
retained failures. Twenty-one source/evidence corruption controls reject. The actual canonical
merge14fbefde has exactly the qualified tree7ab180aa. Publication and integration are explicitly authorized. The current successor
retains the exact original NUT dispatcher bodies and binds their fixed95a3bd57
source/evidence gate plus14 controls. All18 current annual cases pass. The old
performance research validator body passes, while its CLI KeyError and missing
source negative remain recorded as predecessor failures, never PASS. No
historical capability or master-row promotion is claimed.


## Canonical receipt

All18 feature PR workflows and17 repair PR workflows terminate SUCCESS. Original
postmerge run39673936142 failed at the old PERF01 top-adapter lock and is retained
as FAILURE. PR1363 adds only the two exact admitted source registrations; every
original immutable oracle and architectural/native assertion remains. Hosted
job119481737620 and the actual canonical local replay report
FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS. Six other actual PR1362 merge
workflows pass. Actual repair tree7ab180aa equals the complete qualified head;
its duplicate broad postmerge Actions are NOT_SELECTED_IMPACT. Local actual
source/evidence,21 controls and full original native O0/O2 replay pass.

The existing owner and MC_SOL01_SWP_WATER_HOSTED_20261021.json hold exact commits,
run IDs, source identities and raw native success/failure evidence. Complete
historical migration and every whole master capability remain open.
