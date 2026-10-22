# Weather surface saturation repair

Status: proposed production repair with bounded native evidence, 21 October 2026.
Baseline: 95a3bd5721a4dfb4c0c38823c475ff55b95bee57. Diagnosis: PR1361.

## Physical composition

Nonirrigated file weather passes immutable gross rain and potential soil/pond
evaporation into the existing dynamic B1.10 surface provider at every actual
trial, sibling and retry. The provider resolves flux/head switching, ponding,
evaporation and runoff. Rain is not clipped to Ksat. Runoff is not a balance
residual. Accepted surface amounts come from selected accepted substep receipts,
prevalidated before the physical commit. Rejected windows publish no receipts.

The composition is bounded to Reference, default MvG, conductivity mean1,
free bottom7, live prescribed crop uptake and optional restricted soil heat.
Irrigation and other existing physics retain their existing routes. Solute,
macropores, elasticity, hysteresis, KSATEXM, power tails and response/tangent
compositions are not expanded by this repair.

## Numerical contract

The weather route enables the continuous Mualem curve through the inherited
near-saturation early-Ksat shortcut. Retention is unchanged. Stable log1p/expm1
arithmetic recovers the linear retention deficit directly from head before
absolute water content rounds to saturation. Storage increments across zero
use that same piecewise linear retention expression. Prepared parameters are
copied into worker-owned storage before activating the route.

Interior and boundary conductivities follow each Newton candidate. Jacobian
terms use the same provider, including analytic near-zero dK/dh and free-bottom
dK/dh. The top adapter provides a separately typed total dqtop/dh. For the
arithmetic-mean head branch with fixed atmospheric demand and no macropore/implicit
pond-evaporation coupling, this chains analytic dK/dh through the existing exact
fixed-K pond/runoff derivative. Other branches retain full-boundary finite
differences. The scalar conductivity API adds an optional derivative output;
existing callers and default values remain unchanged. Newton updates remain in physical pressure head.
Iteration/backtracking caps and physical acceptance criteria are unchanged.

For this route only, Newton's per-cell rate criterion is tightened to at most
mass_tolerance / (16*n*external_interval_duration). Its total rate criterion is
at most n times that value. The existing machine-level residual floor remains.
Parameter configuration restores the requested criteria before each interval;
this tightening does not accumulate. The hard transaction mass gate is unchanged.

The original full-versus-two-half transaction controls temporal error. Its
weather norm is the maximum of unsaturated head differences, sum of absolute
cell water-content differences times thickness, pond/groundwater differences,
and endpoint Darcy-rate differences times trial duration at all interior,
free-bottom and wet-surface faces. Saturated head is algebraic and is not given
a uniform smooth-head error guarantee. Endpoint displacement indicators are
not claims of exact equality of integrated sibling receipts. Only the selected
two-half trajectory commits. Existing unrelated certificate norms are unchanged.

## Qualification and limits

The original wet4 case is a 30cm/four-cell illustrative crop column, 97 days,
64 external intervals per day, with 908mm rain. It is not a field calibration.
Native O0/O2, finite tolerance points, independent gross water closure, wet-state
reconstruction, rejection after private progress, original weather profiles and
unchanged before/after default solver contracts are selected. Failed or censored
prototypes remain evidence. Results and current limits are recorded in
`benchmarks/performance/PERF01_WEATHER_SURFACE_REPAIR_STATUS.json`.

The branch is a proposed code successor. Existing frozen owner/admission guards
are not declared PASS merely because focused native checks pass. Full FCI and
unrelated low-air/RossFast stress are not selected solely for shared-file changes.

The fixed-step release probe intentionally requests a retry at its largest
step and converges for each of four smaller trials from the unchanged base.
It does not promise fixed-step convergence through every saturation crossing.
The actual adaptive 97-day wet run exercises the full transition. The 1e-6
refinement was censored after 180 wall seconds with 32 complete days; it is
not a completed reference or evidence of a physical failure. This run competed
for the pinned CPU with other qualification jobs.


## Day43 strict desaturation successor,22 October2026

The retained proposed repair stops at day43/window18 at a1e-6cm temporal budget.
A print-only trace isolates33 solver rejections and zero mass/temporal rejections
at internal time42.287931002257956day. The bottom head is positive
2.1596686945289869e-13cm and must become negative. More Newton iterations or
backtracking alone do not repair the corner. The strict run is FAILED, not censored.

The successor damps only a Newton trial entering the unsaturated side: for
solve-entry0<=h<=sqrt(epsilon)*1cm, current Newton h>=0 and tentative
-1cm<h<0, use h_trial=-(1cm)*(abs(h_trial)/(1cm))**3.
This is a nonlinear trial step using the inherited1cm head normalization,
not a changed constitutive law or accepted-state correction. The negative-side
Mualem slope diverges near zero; the full head step can overshoot its very small
negative root. The existing line search evaluates the complete physical residual
at the damped trial. All balance/head/pond gates, iteration/backtracking caps and
transaction tolerances remain fixed. Negative old heads and the unselected
consistent-provider flag retain the previous trial update. This differs from
the discarded global cubic-coordinate prototype: the Jacobian, unknown and
all already-unsaturated Newton updates remain in physical pressure head.

A small actual solver reproducer uses the exact trace base and unchanged day43
root/atmosphere forcing. The successor must converge at1e-3,1e-6 and1e-9day
where the predecessor fails even with80iterations. Full wet4, O0/O2, rollback
and affected default preservation remain separate gates. No broad admission is
inferred from this small probe.


The first broader crossing-only prototype failed the full run on day35 and is
retained as FAILED. The selected successor restricts damping to solve-entry
heads within sqrt(machine epsilon)*1cm of zero on the saturated side. It leaves
ordinary wetting and finite positive-head crossings unchanged. In particular the
original largest-step retry test is restored byte-exact, including its immutable
base assertion; the new exact day43 regression is additive.


The solve-entry restriction alone also failed full wet41e-4 and1e-6 on day36.
The selected implementation therefore always tries the original Newton solve
first. Only its actual iteration exhaustion, with a qualifying solve-entry
corner and no macropores, permits one restart from a deep copy of the complete
entry solver state. That restart activates the damped crossing trials. No
successful ordinary solve is replaced. Initialization recomputes K, all face
means, provider tuples, root/source inputs retained for the same immutable
forcing, residuals and Jacobian from that restored state. The second solve has
the same MaxIt/MaxBackTr and physical gates. Actual total iterations/work include
both phases; the maximum local work can double. Failure of the second phase
retains the ordinary retry-advised path. There is no committed-state correction.


## Current bounded successor result

The original-first restored corner restart completes the actual908mm/97day
wet4 run at1e-6,1e-4,1e-3,1e-2,0.1and1cm. The1e-6strict run is no longer
censored:248.693691userCPU seconds,97complete days, zero exit. Maximum independently
reconstructed daily gross closure across all six cases is below4e-13mm. Full
O0/O2physical/work identity at1e-3, active wet-day35reconstruction, rollback,
exact O0/O2corner success and forced-corner-failure nonmutation, six original
weather profiles and two unchanged solver contracts per optimization pass.
Full1e-6seasonal execution is O2only. This is a bounded local successor, not
canonical admission or a portable speed/field-calibration claim. See
`benchmarks/performance/PERF01_WET4_REVIEW_20261022_RESULT.md` and its companion
summary and source-bound evidence archive. Earlier censored/failed observations
and the previous frozen capsule remain historical and are not rewritten as PASS.
