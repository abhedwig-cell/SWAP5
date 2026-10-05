# Joint surface continuation and temporal head-policy falsification

Date: 2026-10-05. Workstream PPA; unit PPA-WU05-A28-WORK-PRODUCTION.
Branch `work/a28-rfm-production-work`; baseline76f23dfa75e74f8836aaeb3cce79b24225aa56fd.
Canonical observed9605fbb1622d96f4691117f66264f13b6dd3a47b.
Implemented/tested research only; not canonically admitted or production qualified.

Decision: **COUPLED_RFM_BLOCKED**. This continuation resolves the previously
unsupported positive-pond composition under an explicitly new reduced physical
profile, not the full24-window/activity/receiver/production contract. A28 remains
component-only. No new Actions runs; all development, compilation and experiments
were local. Earlier strict failures and the practical A28 approximately2% envelope
are unchanged.

## Contract and implementation

[Joint preregistration](PPA_WU05A28_JOINT_SURFACE_PREREGISTRATION.md) defines
`EXTERNAL_SUPPLY_PARTITION_V1_RESEARCH`: partition only new atmospheric supply,
using the existing A11 expression upstream of local pond storage. Existing pond
belongs exclusively to B110's dynamic matrix surface; it is not fed into RFM again.
Only the separate upstream activation request has pond=0; the physical pond state
is never reset. This is **not** a source-faithful general ponded preferential-entry
law. No evaporation/external stage is supported by this profile.

`tests/fpe/support/mod_fpe_a28_joint_surface_receipt.f90` validates partition and
joint surface receipts. Its generated opt-in backend replaces matrix-top external
receipts by total rain and runoff once, retaining distinct deep output. The joint
oracle is rain*dt+oldpond=pref*dt-qtop*dt+newpond+runoff. No second persistent pond
store or double atmospheric/RFM input is introduced. Trial ownership, accepted
checkpoint, discard/replay and publication remain F-GC controlled. Read-only pond
and soil-matrix getters separate soil from the older matrix-plus-pond inventory.

Existing production execution and A11/A15 defaults are unchanged. The separate SCV
branch `work/sw-rib-top03-scv-temporal-context@fd67ef40a8e91be20127cf4730c52bfb028b7327`
was inspected, not inherited or overwritten. Its storage/contact/stage assumptions
and temporal pilot are not admitted dependencies. Invariants3/7/11/13/28/30 remain
the ownership/conservation boundaries. The previously registered anchored terminal
pressure prototype remains enabled here and is **not** an exact-preserving repair.

Frozen policies distinguish internal balances1e-5 cm, nonlinear head abs/rel1e-6,
RFM physical/accounting1e-12 cm, transaction/posttrial mass1e-12 cm, temporal head
and each water/pond/RFM/GW channel1e-5 cm, and coupling flux1e-15 m/s. Ceiling16384
is the earlier resource-only diagnostic limit, not a production recommendation.

## Results

| Experiment | Accepted windows | Result |
| --- | ---: | --- |
| Initial joint profile |19/24|Predictor20 reaches substep ceiling|
| Pond getter observation |17/17 requested|All17 common rows bitwise equal; not a24-window gate|
| Fresh guarded joint replay |19/24|Same predictor20 failure, common rows bitwise equal|
| Correctly generated bounded temporal observer |19/24|Same failure and bitwise rows|
| Separate1e-3 cm temporal head pilot |15/24|Predictor16 FD-stability failure; rejected|

Service tests pass O0/O2 with bounds checks: positive pond, nonzero pref input,
runoff, exfiltration, invalid values/overdraw, bad closure and nonmutation. Unchanged
A11/A15 controls pass O0/O2. Fresh full builds and initial field-depth FD pass.
There are17 retained positive-pond candidate receipts, including9 with both
positive old pond and nonzero preferential supply. Independent surface closure is
<=4.337e-19 cm. These are trial/substep observations, **not accepted endpoint pond**:
the accepted19 endpoints all have pond=0. Independent19-window inventory vs direct
receipt agrees within5.205e-16 cm, local mass residual<=2.498e-16 cm and groundwater
interface reconstruction difference<=6.072e-18 cm. These checks do not assign a
receiver to nonmatrix external output (RFM deep plus any runoff).

Documentation source checks and `python -m mkdocs build --strict` pass. Generated
site output is removed after verification; no user source or evidence is deleted.

Predictor20's failing first sample:143156 attempts,126772 retries/temporal
rejections,16384 accepted substeps,1006080 nonlinear iterations/Jacobian builds/
linear solves/backtracking attempts; zero solver and mass rejections. It reaches
.19872460937508943 day, max step mass residual1.2741304644242049e-14 cm and aggregate
reported trial mass0. The observed final whole/half pressure discrepancy is
5.226662447981312e-4 cm, matrix water discrepancy5.851847673099542e-8 cm, with
pond/GW/RFM/endpoint channels zero. Saturated-block pressure response dominates
that rejection. This is not evidence that all previous temporal events share an
identical mechanism, nor evidence of an internal nonlinear balance failure.

Accepted head excursion=.08439353643465708 cm, below registered.1 cm. Accepted RFM
storage remains0 in both tiles, below the required1e-10 cm floor. Preferential
throughflow is active, but persistent-storage gate and explicit deep receiver
remain unmet. Full24 completion alone would not satisfy those independent gates.

## Separate head/water pilot: negative result

[Prospective registration](PPA_WU05A28_TEMPORAL_HEAD_POLICY_PREREGISTRATION.md)
precedes generation/run. It changes ONLY the research temporal head channel to
1e-3 cm; water channels remain1e-5 and mass/coupling/solver/physics remain fixed.
No universal TOL and no external mass relaxation was used.

Pilot predictor16 fails the existing3-delta relative spread gate:
.0033114827088481001 > .001 (0.331% >0.1%). Individual samples complete, replay and
discard successfully; their different adaptive paths produce delta sensitivity.
The existing failure-only diagnostic ladder gives derivatives15.71016045,
15.53731906,15.65830823,15.69287657,15.70108516,15.70324856,15.70188657 day at
deltas1e-7,3e-7,1e-6,3e-6,1e-5,3e-5,1e-4 cm/day respectively. A wider-delta plateau
is diagnostic, not permission to recalibrate or widen the frozen FD gate.

The prospective19-window comparison cannot execute with only15 accepted rows.
Do not lower its overlap requirement. Descriptive15-prefix differences are small
(head<=1.033e-5 cm; matrix+pond<=4.344e-6 cm; floored tile flux<=.262%), but do not
qualify the failed predictor or unobserved trajectory. Independent pilot-prefix
mass residual<=2.603e-16 cm. The preregistered stop rule ends this policy experiment:
no headbudget retuning, cap increase or acceptance/delta relaxation follows.

## Performance and production disposition

The17-window observer records109.830 s execution,78.757 predictor,31.015 corrector,
.034 MODFLOW and52.848 sorptivity CPU seconds;1137300 exact64 evaluations and
72787200 panels. This is a noisy **qualification ladder/replay** run, not the proposed
single centered-pair production predictor and not a repeated representative
MultiSWAP benchmark. Compilation/setup/download are excluded, but no material
production speedup is inferred. A28 was not run after the exact/activity failures.

Internal balance1e-5 alone showed identical work to1e-10 in the earlier isolated
frontier, and remains unqualified as a production default. This continuation does
not make it unsafe by a demonstrated mass failure; it demonstrates that changing
that criterion alone does not resolve temporal pressure/FD instability. No single
production predictor pair, robust persistent-storage fixture, live original-physics
exact24, practical A28 envelope or production performance qualification exists.

Next safe design work is a separately specified temporal/FD execution policy that
controls pressure accuracy **and** a reproducible FD response across adaptive
paths, together with physical-profile validation and explicit nonmatrix receiver
ownership/persistent RFM geometry. Do not stack additional tolerance/cap changes
onto this rejected pilot or relabel the new physics as preserved exact production.

## Evidence scope, deviation and reproduction

The bundle `evidence/PPA_WU05A28_JOINT_SURFACE_EVIDENCE.json.gz` retains complete
ordinary logs, result JSONs, inventories, generated source postimages, source/object/
library hashes and local preregistration chronology. Its manifest is
`evidence/PPA_WU05A28_JOINT_SURFACE_MANIFEST.json`. No repetitive trace trimming.
MODFLOW6.8.0 archive SHA25633edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e;
libmf6 SHA2568589fceef108757f62bb82cb2b0282562172312a75187b70ae7a06f4bd15fbf9.

Protocol deviation: bounded-observer generation at01def1a0 failed with an
IndentationError. The shell lacked set-e and continued compiling the previous
valid1ea66256 generated source. Thus `joint-final` qualifies that guarded
pond-observation postimage, **not** a temporal observer. Commit177b796b fixes placement;
generate-only succeeds and `joint-temporal` is the actual bounded observer run.
The failed-generation log is retained. Initial39c478c3 guard postimage and later
six-value guarded source are separately hashed, not silently rebound.

```bash
python tests/fpe/run_fpe_a28_joint_surface_unit.py /tmp/a28-joint-unit
A28_FIELD_DEPTH=1 A28_SEPARATE_RFM_TOLERANCE=1 \
 A28_PARTITION_AWARE_PREFLIGHT=1 A28_TYPED_STABLE_STORAGE_INCREMENT=1 \
 A28_POSTFILL_TERMINAL_PRESSURE_PROTOTYPE=1 A28_ANCHORED_POSTFILL_PROTOTYPE=1 \
 A28_BOUNDED_TRANSACTION_PROPOSAL=1 A28_CORRECTOR_DIAGNOSTICS=1 A28_RFM_PREPARER_DIAGNOSTICS=1 \
 A28_JOINT_SURFACE=1 A28_JOINT_SURFACE_DIAGNOSTICS=1 \
 A28_TEMPORAL_COMPONENT_DIAGNOSTICS=1 A28_TEMPORAL_DIAGNOSTICS_BOUNDED=1 \
 python tests/fpe/build_fpe_a28_coupled_local.py /tmp/a28-joint-reproduce
A28_H0_CM=-45 A28_DT_DAY=.01 A28_RAIN_CM_DAY=10 \
 A28_SOLVER_BALANCE_TOL_CM=1e-5 A28_HEAD_ABS_TOL_CM=1e-6 A28_HEAD_REL_TOL=1e-6 \
 A28_PREDICTOR_BASEPOINT=accepted_flux A28_COMMITTED_SUBSTEP_LIMIT=16384 \
 A28_PHYSICAL_PROFILE=EXTERNAL_SUPPLY_PARTITION_V1_RESEARCH \
 FGC45_MULTISWAP_LIB=/tmp/a28-joint-reproduce/libfgc45_multiswap.so \
 LIBMF6=/path/to/validated/libmf6.so A28_RESULT=/tmp/exact.json \
 python tests/fpe/test_fpe_a28_coupled_windows.py exact 24
```

For the negative head pilot add `A28_TEMPORAL_HEAD_BUDGET_CM=1e-3` at build and
execution, omit the temporal observer, and request24. Metadata flags are not
library introspection: match generated-source/library hashes, not JSON labels alone.
Extract archived files to a directory, then run the bundled joint analyzer there;
inventory reconstruction requires the paired complete log and result.
