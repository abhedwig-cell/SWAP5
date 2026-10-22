# PERF01 failed-Newton work: controlled research

Baseline: canonical f4ef44cb20cfb73ae7a582487790a4eb0292b144, after PR1361.
Owner: PERF01 numerical-cost research, with HY/TX invariants held fixed.
This is an experiment on generated executables, not a production source change
or an admitted numerical default. The repaired production source is immutable.

Question: can repeated exhausted Newton work be reduced without material
changes in accepted water storage, runoff, bottom flow or crop response?
The previous source-bound observer found62% of wet4 solver CPU in failed
calls;98.6% of failures had no internal boundary-regime switch. Warm start
was slower and remains OFF. Begin with the existing97-day fixture, especially
day84, and compare227/908mm rainfall at the same1e-3cm temporal budget.
The user excluded new1e-6 runs; no tolerance relaxation is selected.

Prespecified variants: original20 Newton iterations, caps12 and8 through the
existing numerical input; and an isolated generated HeadCalc which terminates
the current Newton phase if all8 backtracking candidates fail to reduce its
squared residual and the maximum compartment residual is still above its
unchanged balance criterion. The existing exhausted-phase corner fallback,
state restoration, failed-status reporting and smaller-step retry remain intact.
This last variant is research-only and may discard an eventually recoverable
nonmonotonic Newton trajectory. Preserve failures rather than changing gates.

Reverify every original build source, generated observer source, actual object,
compiler and executable before sharing the256-provider closure. Relink only
the driver/generated HeadCalc: expected5seconds per executable. Screen all
three candidates at O2 for both rainfalls, expected60seconds total. This is
new numerical execution policy and therefore needs actual physical screening,
not a claim of preserved behavior from source dependency identity alone.

Screening: all97days complete, independently reconstructed daily gross closure
below1e-8mm, max daily storage spread<=0.01mm, total runoff/bottom differences
<=0.05mm, crop biomass/LAI/transpiration differences<=1e-10 in this prescribed
uptake fixture. These are the previous warm-start research screening bounds,
not replacement production convergence or mass gates. Record pressure heads
and water-content spread separately. No uniform saturated-head guarantee.

For any promising candidate, repeat checked O0/O2 and wet-day35 reconstruction,
then three alternating serial baseline/candidate pairs per rainfall (expected
90seconds). Compare work counters and day84 as well as measured CPU. Do not
run timing pairs concurrently with compilation. Retain every raw stream and
failed/censored arm. No portable speed or broad field-accuracy claim.

Production promotion, if justified, requires a separate exact implementation,
direct failure/rollback/corner tests and the existing affected source/native
admission owners. Full F-CI, highest low-air and RossFast expansion are not
selected for these generated research executables. No physical law, surface
formula, accepted-state ownership, restart or mass tolerance may change.
