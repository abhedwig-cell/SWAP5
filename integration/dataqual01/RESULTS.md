# DATAQUAL01 measured migration batch

Tested candidate on canonical baseline `e47e98c6b8e614c75284c831925a34d7756cd4b0`.
Infrastructure integrated by PR1460, actual merge43fd2f821d88fc0c80b7a2563ccfb020a62543ba;
complete merge tree exactly matches54db8c9d8626bdfa36b0ccb22551ca5f535b7f04.
Source/raw owner checks pass on the actual merge. Experimental
success is not production admission. Machine authority: `STATUS.json`, `RESULT.json`
and `summary.csv`; complete raw evidence includes development failures.

## Executed result

45 scenario executions across final O2/O0/preservation/resume batches:29 physical
completions,12 failed/rejected executions and4 timeouts. A separate day2 continuation
is also censored. These are executions, not45 independent original historical
projects; several deliberately repeat the same configuration under another build.
The main22-case O2 batch has17 physical completions,2 intended rejections and3
censored cases. Fifteen of16 short pairwise configurations complete; the remaining
one times out. The binary design covers every level pair for groundwater, pond
storage, rain amount, Ksat and empirical oxygen. Boundary cases additionally vary
rain timestamps, reference evaporation, air temperature, soil storage and drainage.
Disabling macro/heat is deliberately rejected by the existing native composition;
this work does not implement arbitrary activation/deactivation or alternate crops.

The original112-node/five-domain project completes2days at checked O0 and O2.
State, temperature, budget, progress and restart physical payload are byte-exact to
the admitted predecessor. New cost and groundwater diagnostics are also byte-exact
between O0/O2. Existing joint and rootless native trace/replay stdout remains exact.
Existing root empirical-oxygen/component and invalid/nonmutation contracts pass
O0/O2. Six new corrupt/foreign file controls reject before output publication.
Full/split/restarted endpoint checks are exact. Maximum independent accepted
cell/matrix/combined/supplied-source certificate among successful final runs is
`1.1695939355904628e-14 cm`; no solute/N qualification is attempted (SWSOLU0).

An explicitly selected empirical-oxygen case completes1day, with accepted oxygen
uptake reduction `0.0005534549859084265 cm`, exact O0/O2 results. Identical raw
input in production is rejected. This exercises the existing factor in the real
root procedure; it is not a copied formula or an option silently disabled to run.
Negative PONDMX and out-of-domain oxygen thresholds reject. Altered soil storage
also exposes an original SHRINKPAR input-consistency limit; this is not bypassed.
Saturated startup remains an unresolved hard exclusion, not newly qualified.

## Numerical diagnosis

The frozen/literal entry run times out after15s, with complete source windows
through1.076days,2700 returned-window attempts and2291 temporal rejections.
The explicit already-admitted corrected-entry baseline completes2days:6524 returned
attempts,3306 temporal rejections,62112 nonlinear iterations and no solver/mass
rejections. These costs do not establish a portable speed comparison: builds and
other probes sometimes ran concurrently.

Reusing the exact fresh day2 file, a20s continuation completes source windows
through2.495days:2043 attempts,1040 temporal rejections,20401 nonlinear iterations,
zero recorded solver/mass rejections. In-flight work after that boundary is not
included. Existing detailed diagnostics show accepted in-flight steps around
2.4975days as small as roughly1e-6days and a full/half head discrepancy about
0.0244cm in one recorded trial. No tolerance was changed. The committed complete
window and fine-grained in-flight diagnostic time are explicitly different.
A wet GWLI=-40cm case does not finish even its first source window within20s.
This is a numerical cost diagnosis, not proof that the physical input is invalid.

PR1457 separately contains evaporation and continuous-wall/feedback changes and
reports141days on its own candidate. It is not canonical and its evidence is not
inherited here. Repeating tiny solver changes on canonical would duplicate that
work without resolving its source/physics/equivalence questions. No new physical
law, numerical tolerance or speculative solver repair is included in DATAQUAL01.

## Reference limits and next priorities

Rounded frozen4.3.1 output supports a descriptive comparison only. Native GWL
minus reference is+0.178251cm on day1 and+0.892564cm on day2. Matrix+rapid daily
drainage deltas are+0.001499cm and+0.008411cm. The drainage mapping is provisional;
those nonzero differences remain open, not a parity PASS. The canonical native
application still yields zero soil evaporation in this fixture; PR1457 addresses
a missing positive surface-demand connection. Thus a tiny conservation residual
alone cannot establish faithful historical physics.

1. Reconcile PR1457's missing evaporation/source forcing and reference deltas;
   preserve the experimental admission separation when rebasing its shared file.
2. Prioritize the residual/Jacobian and current-profile groundwater/drainage
   coupling implicated by costly temporal refinement, using retained failing
   states rather than rerunning the unchanged prefix.
3. Extend native configuration availability for useful inactive-process and crop
   routes only where owners actually implement their lifecycle; never relabel
   missing composition as a qualification gap.
4. Run longer selected successful configurations and independent reference
   comparisons; promote production only through a separate explicit decision.
5. Expose in-flight transaction progress/checkpoints before large batches, so
   censored windows do not hide the bulk of their iteration cost.

## Reproduce

Build with `python tools/solute/build_project.py --native-water --optimization O2
--output /absolute/build`. Execute `python tools/solute/run_dataqual_batch.py
integration/dataqual01/scenarios.json --bundle /absolute/build --output
/absolute/new-results`. Other supplied manifests select boundaries, corrections,
O0/O2 exactness, preservation and same-batch restart reuse. Existing executable
and current source fingerprints are checked before every native preparation.
