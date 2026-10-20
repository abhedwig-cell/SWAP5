# Historical gross atmospheric N: owner decision and implementation contract

Status: locally qualified source-bound successor; canonical admission pending. Baseline canonical
`d443dced3313e2602fdea4cbd1a6cb566f53fb0e`.

On20 October2026 the programme owner selected option1: preserve historical
gross atmospheric N loading, original process order and the original aggregate
ponding convention. This resolves the previously open reference choice. It does
not authorize a corrected surface NH4/NO3 store or new runoff-mixing equations.

Original management_soil lines400..402 supplies
`0.01*(igrai+isnrai+igsnow+igird-iintc+irunon-iruno)/outper` in m/day to
Wofost_SoilWaterN. Soil evaporation is separate. Original analytical transport
uses that top term in its production/input coefficient while independently
using initial/final water contents. Thus rain4mm and evaporation4mm must still
load atmospheric N even though net soil-water input is zero.

The existing mineral/reactive/crop/calendar owners receive an optional
`historical_top_water` argument, in m/day, containing that source aggregate.
It is not a water source for Richards and is not substituted into the hard
water closure. The accepted net carrier remains the only water authority.
In the existing analytical solution and external-input receipt only, the
explicit historical argument replaces positive net infiltration. Organic
reactions, source ordering, source crop demand and all ownership are unchanged.
Absent the argument, existing admitted endpoints must remain byte-identical.

This first executable candidate covers finite nonnegative historical aggregate
rates0..100m/day, the same bounded numeric scale as the existing mineral carrier.
Negative aggregates, including any runoff-from-prior-pond case producing one,
remain rejected pending direct source/positivity qualification. No claim of a
new physical pond-N balance is allowed. The accepted aggregate convention is
preserved rather than inferred from infiltration. Whole HIST remains open for
this outstanding domain, automatic original atmosphere producer binding and
the previously recorded native input/output/original-model envelope.

The joint runtime requires explicit `atmospheric_n_surface` opt-in and rejects
invalid historical input before a water trial. A new optional forcing value
does not add committed state, cumulative inventory or a restart schema. Source
identity continues through existing immutable c_top and native parameter vectors.
Historical gross forcing must be supplied again for each resumed interval, like
weather; rejected candidates publish neither water nor N.

Affected invariants are the existing atmospheric contract's1..4,7,9,11,13,
21..23,25,26,28..30. MC-NUT01 owns this extension; shared solver, matrix, age,
surface stores and MC-SOL01 production are read-only. No RossFast extension.

Selected qualification: four-provider mineral O0/O2 with original unmodified
watern,18 combinations of gross input, water endpoint and sorption, invalid
input rollback and opaque continuation. Actual323-provider Reference
Richards/WOFOST81/Soil-N O0/O2 executes all original default/source124/three730
profiles and one new730-day gross profile. The new profile retains humus,
two crops, harvest/fallow/successor, chemical and actual hydraulic rejected
trials, and six fresh-process transition continuations per optimization.
Water/N tolerances and the original drying-stress failure are unchanged.

Expected full actual gate cost900seconds. Existing owning retained/thermal/TCS6
and historical evidence validators remain admission requirements, not inferred
PASS from a small process test. Changed production providers must be bound to
fresh execution and immutable predecessor endpoints before any canonical merge.
Full moving F-CI is not automatically selected by this forcing-only owner seam;
check actual shared-semantic impacts before selecting it. No tolerance, native
assertion or corruption control may be weakened to accommodate new evidence.

## Completed actual qualification

GNU Fortran13.3 O0/O2 passes18 mineral original-source combinations and9 full
original reactive chemistry combinations per optimization. The actual shared
production closure executes the source124-day case, original default and all
three admitted730-day rotations plus the new gross730-day humus rotation.
All10 original endpoints remain byte-identical. All48 transition fresh-process
continuations match their uninterrupted endpoints. Gross-profile hydraulic
rejection, invalid source rejection, stale environment and clean-only rejection
leave serialized state unchanged. The complete retained owner, thermal/empty
phases and all54 TCS6 native trajectories pass with their original assertions.

Whole-system N in kg/m2: initial0.66569153059254693; external input
0.019448273121288662; external output0.0080723769466728382; final
0.67706742676716480; residual-1.9931972738973514e-15. Relative residual,
defined as absolute residual/(initial+input), is2.90918329820151e-15.
Maximum daily N residual is1.8432074324546384e-15kg/m2 and maximum accepted
water-step residual4.986462631695332e-15cm. Gross atmospheric N itself is
0.004m/day *0.002kg/m3 *730days =0.00584kg/m2 =58.4kg/ha; it is booked once.
The unchanged hard tolerances remain daily1e-12kg/m2, cumulative1e-10kg/m2
and water1e-10cm.

New gross endpoint SHA256:
`f43aff865026e2f26337c7c87c1c8f5446346492539de2dcaf709304ee2b33af`.
The actual physical gate cost227.946s compilation,0.356s linking,138.960s
main native execution and154.508s fresh restarts. These are local measurements,
not portable field-model speed claims.

Raw evidence is
`integration/audits/evidence/MC_NUT01_HISTORICAL_GROSS_TOP_20261020.tar.xz.b64`,
decoded SHA256
`1ab68b9687bad73082762e6956f1f0e458732058d41ffc6717a5fc2d351069d3`,
235300compressed bytes,4432file members. It retains raw logs, native snapshots,
original/generated literal sources, source hashes, compiler/deb/runtime hashes,
failed preflight receipts and the original predecessor owner report.
It excludes reproducible objects/modules/executables. The local physical
execution commit6373946 and remote checkpoint efe173a9 have the identical
tree d327f938; later evidence/guard/docs commits do not alter compiled physics.

The strict successor verifier is
`tests/nut-crop/verify_historical_gross.py`. It fixes the exact14-file scientific
ownership boundary against d443dced, requires current hashes, checked compiler/
link/native inventories, immutable old endpoints,48 actual process continuations,
hydraulic/chemical rollback and all54 TCS6 records. It also executes the unchanged
old canonical owner on its exact original Git worktree. The original core-CI
compiler footprints prove none of the seven changed NUT providers was compiled
there; their broad uncompiled source inventory is not confused with executable
dependency. Existing baseline source/evidence guards are neither edited in that
worktree nor waived. Eight new corrupt-evidence controls and the original18
controls pass. Scoped dispatch in the existing NUT and CI authorities requires
this complete proof; it never declares full HIST admission.

## Reproduction

Use an exact historical/source checkout and the recorded GNU13.3 toolchain.
Generate the existing reproductive literal, then execute the existing mineral,
reactive, hist-complete, retained-joint, retained-phase and TCS6 runners with
fresh output directories. Set the explicit FC path where required and unlimited
process stack; OMP_NUM_THREADS=1. Owning selections and the exact commands are
retained in the evidence event files and the existing work-unit status.

```bash
export PYTHONDONTWRITEBYTECODE=1
python tests/nut-crop/verify_historical_gross.py --self-test
python tests/nut-crop/verify_historical_gross.py
python tests/nut-crop/verify_hist_native_successor.py
```

The source checker requires the pinned predecessor commit and original capsules.
It creates an isolated original predecessor worktree and runs its unchanged
admission guard. A supplied SWAP5_GROSS_PREDECESSOR_WORKTREE may reuse an existing
clean exact d443dced worktree, but its HEAD, tracked content and foreign executable
sources are checked each time. No numerical PASS is inherited from that worktree
for the changed NUT branch.

General automatic source-atmosphere binding and negative aggregate/pond cases,
fractional/general native syntax, extended diagnostics and a full original-model
multiyear oracle remain distinct open envelopes. The owner reference choice is
resolved. RossFast, aquifer and MC-SOL01 production are outside this successor.
