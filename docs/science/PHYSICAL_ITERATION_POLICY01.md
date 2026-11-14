# Physical-convergence proposal policy assessment

This is a numerical-policy change under investigation, not a correction to the
original NUMBIT rule. The baseline and causal observation are owned by
[SaltFarm localization](SALTFARM_PRESSURE_LOCALIZATION01.md) and
`integration/f-ci/physical-iteration-policy01/SELECTION.json`.

Original TimeControl(3) increases dt when actual NUMBIT is at most NUMBIT_CRIT,
and decreases dt when actual NUMBIT is at least MaxIt. Generated strict-water
HeadCalc adds auxiliary Newton iterations after original convergence, both to
satisfy the stricter accumulated mass gate and to polish beyond its first pass.
Those auxiliary iterations currently influence the same increase trigger.

The selected hypothesis separates only that growth trigger. The proposed counter
records the first iteration of the final consecutive original-converged streak.
Any subsequent original nonconvergence clears it. It is reset on every HeadCalc
entry, including a rejected/retried attempt. The strict gate and extra original
Newton iterations still run in their current order. Actual NUMBIT, MaxIt,
iteration histograms and high-iteration step decrease remain unchanged. Growth
using the physical count is additionally disabled when actual NUMBIT reaches
MaxIt. No guard is rounded and no iteration is skipped.

This counter is transient private-worker control context, not physical state.
It is assigned before every possible next-step use; no value is inherited from
a preceding call, day, restart or different worker. An admitted implementation
would require explicit project/build numerical-policy identity and fresh own
restart qualification. Legacy adaptive and configured daily actual-count policies
must remain explicit selectable identities, with no failure-driven fallback.

One private SaltFarm discriminator activates the alternative on day1009, preserving
all1008 preceding daily heads/stocks/flows/uptake exactly. Its corresponding
read-only paired control is already saved; no control trajectory is repeated.
The local candidate passes all unchanged water/solute guards, native6.013s.
The hosted paired candidate is run43553332658 on carrier
c48aef4603cae77e9cc6fe004b1423e21bc0dbda. It does not replace a supported BUILD
or load a foreign checkpoint, and is not production qualification.

Next decision depends on that paired result. A material reduction would justify
an explicit candidate policy, followed by relevant fresh O0/O2 complete named
trajectories, exact own restart, unchanged balances and coupling/source refusals.
It would not prove scientific equivalence or authorize relaxing any original
criterion. A failed or immaterial result must remain visible and lead to a
simpler strategy rather than repeated threshold adjustments.


## Qualified bounded implementation

The paired private discriminator completed SUCCESS and reduced the isolated
SaltFarm day1009 pressure difference from0.0018243055500306582 cm to
1.1368683772161603e-13 cm, while preserving the complete preceding1008-day
prefix. An explicit candidate was then implemented in the existing generic
generator. A real broad-candidate Hupsel attempt refused day364 at
-1.0033485153826405e-10 cm under the unchanged1e-10 gate. Its full failure and
binary evidence remain preserved; it is not admitted or hidden by a fallback.

The qualified selection is therefore explicit per registered numerical profile:

| Project | Selected policy |
| --- | --- |
| Grassgrowth1827 | configured-dtmax-daily-v1 |
| Hupsel1096 | configured-dtmax-daily-v1 |
| SaltFarm1461 | configured-dtmax-physical-growth-v2 |

This is one generic physical implementation with declared numerical policy
metadata. The original adaptive policy and daily-actual-v1 remain available;
general experimental projects still default to original adaptive behavior.
Explicit experimental v2 use is research, and is not universally qualified.
No runtime failure changes the selected policy. Known v1/v2 mismatches are
refused before output, and the existing source/build/checkpoint binding remains.
The transient counter resets at every HeadCalc call and retry; it adds no
physical restart field. Actual iteration histograms, MaxIt decrease and all
rejection rules are retained. Only the explicit v2 growth trigger differs.

Local fresh O0/O2 checks and
[actual matched Windows/Ubuntu qualification43554537720](https://github.com/abhedwig-cell/SWAP5/actions/runs/43554537720)
pass all three complete periods, exact own native/auxiliary and printed-CSV
restarts, twelve build/source/policy refusals and six external instance controls.
Full-period maximum pressure spreads are1.6189005691558123e-10 cm for Grass,
3.956301952712238e-11 cm for Hupsel, and2.2737367544323206e-13 cm for SaltFarm.
All water/solute limits remain unchanged. Native original heat state is included
in exact own restart; no new independently closed physical energy budget or
whole scientific equivalence is claimed.

Grass/Hupsel generated calculation sources are byte-identical to their preceding
qualified v1 local bundles, and their full local daily records remain exact.
One fresh five-day experimental legacy composition has exact own restart and
identical generated source text to the prior qualified D case after universal
newline normalization only. Other unchanged experimental full cohorts are
inherited by their unchanged policy/generator path; no full repeat is selected.
Source identity still requires rebuilding stale bundles and never rebinding a
checkpoint. The initial generation-anchor failure and a refused stale legacy
bundle are preserved as failures, not counted as numerical PASS.

## Scientific and performance limits

The new SaltFarm route differs from the previous v1 local trajectory by up to
0.6181955413385367 cm in pressure and0.028052418626089093 cm in water stock.
Those are numerical-policy differences, not silently treated as rounding error.
The unchanged original4.3.1 CSV is reused by its exact historical hash, without
a new model reference run. Execution input text is identical; SWP bytes differ
only by CRLF/LF, so byte-identical input is explicitly not claimed for this
archived comparison. All compared active original CSV fields are preserved in
ORIGINAL431_SALTFARM_COMPARISON.json. Descriptively, maximum GWL difference to
that original decreases from0.47797304926800166 to0.018153260029997398 cm;
WTOT from0.028058441110033527 to0.0038408625089800807 cm; drainage from
0.021618043748999893 to0.003333123028999907 cm. This is not a new accuracy bound,
a qualified universal reference or scientific PASS. Existing failed oxygen
criteria and underqualified reference families remain visible.

WORK_COUNTS.json distinguishes converged solves, actual Newton iterations and
original backtracking-cycle counts. Separate-batch wall times are not paired
speedup evidence. Native invocations remain capped at60seconds; compiler setup
is measured separately and dominated Windows hosted waiting. Existing immutable
original providers are reused, while application builds and own restart
qualification are fresh. Full raw qualified local and hosted proofs are retained
with archive/member hashes, alongside the rejected Hupsel v2 attempt.

Next concrete goal: reconcile release/performance acceptance against the
preserved original4.3.1 and current profile evidence. Select only a short matched
SaltFarm timing pair if the existing source/toolchain-bound measurements do not
answer the outstanding performance question. No additional solver/reference
campaign is selected here. The owner's half-hour resumption remains active.
