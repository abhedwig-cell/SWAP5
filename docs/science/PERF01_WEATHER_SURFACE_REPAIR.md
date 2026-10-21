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
