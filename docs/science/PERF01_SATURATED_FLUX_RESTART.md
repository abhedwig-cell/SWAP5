# Saturated prescribed-flux desaturation restart

Bounded numerical repair,23 October2026. Baseline
`2d38fb2d880611d07c27d76d7f8948be3f750e18`. No accepted physical equation,
mass gate, committed state, temporal tolerance or boundary law changes.

The complete original-input comparison constructs one shared30cm/four-cell
SWP/simple-crop/ETref fixture with authenticated1999 weather at1x/4x rainfall.
It is distinct from the earlier WOFOST/free-drainage weather experiment.
Original B1.11 completes97 days. The admitted frozen-conductivity project
rejects water at day53 under1x, and day69 under4x even with30/64 iterations.
Smaller minimum steps and altered inner head/balance criteria do not resolve
the4x rejection. All failures and intermediate observations remain evidence.

After pond depletion, all pressure heads can remain positive while both water
boundaries prescribe flux and the column has a net withdrawal. Actual saturated
storage has zero pressure derivative. The historical pseudo-capacity is
`dt*1e-7`; it regularizes the linear system but creates no actual storage.
Newton can remain entirely on that saturated plateau or overshoot. Smaller
steps do not remove this pressure-offset degeneracy. The earlier free-drainage
near-zero-head restart does not cover this prescribed-bottom-flux configuration.

Preserve every successful ordinary solve. After one failed ordinary phase only,
allow one bounded restart for the plain default MvG provider with no elasticity,
KSATEXM/power-tail/continuous extension, dynamic top, prescribed bottom2,
SWKIMPL0/SWKMEAN1 and no macropores/Picard/consistent-conductivity policy.
Require a completely saturated nonnegative origin, original flux top regime
and positive net withdrawal. Capture that original residual before Newton.

Translate the trial pressure profile by one common offset, preserving its
gradients. Bracket and bisect a candidate offset using the real constitutive
provider and its stable storage-increment method against the original residual
times dt. Restore and retain the original frozen conductivities; candidate
constitutive evaluation must never refresh those physical step coefficients.
The bracket is bounded and unsuccessful construction rejects/reduces the trial.
This creates a numerical initial guess, not an accepted storage correction.
Run the original Newton, surface, compartment, total-balance and transaction
acceptance again. Failed/rejected trials never modify committed state.

Qualification selection: real common-input97-day1x/4x O0/O2, independent gross
water and zero-tracer balances, deterministic repetitions, actual midpoint
restart, an unchanged successful short case, affected source-owner and FSI35
rollback/preservation checks. Measure actual build/native costs. No new1e-6
temporal run, broad F-CI, highest low-air or RossFast expansion is selected.

The existing explicit `historical_zero` solute-exfiltration option matches the
original convention for this zero-tracer comparison. Its default remains
unchanged. Report separate soil/pond evaporation and their total: a small
partition difference does not imply a gross water imbalance. Numerical
controllers and compiler runtime-check policies differ between applications;
observed timings do not establish equivalent accuracy or portable production
speed. Complete qualification/admission is recorded by the work-unit status.

## HIST-INTEGRATION01 continuous-MvG Picard successor

The original-DRA native project reaches the same saturated flux/flux degeneracy
on day470. Diagnostics show alternating saturated and severely dry guesses with
64 exhausted iterations,246 solver rejections and eventual atomic day failure.
The matched continuous-MvG/modified-Picard pair may use the existing one-shot
mass-guided initial-guess restart. Unmatched Picard/plain or frozen/continuous
combinations remain excluded, as do consistent conductivity, elasticity,
KSATEXM, power tails, macropores and scaled areas. Ordinary successful solves
are unchanged. After the failed phase, the original state is restored and the
existing constitutive storage increment brackets the new pressure offset.
Picard conductivity continues to refresh in its ordinary iteration loop.
Physical drainage/root sinks, surface law, all mass/convergence criteria and
transaction/restart semantics retain their existing owners. Qualification and
admission of this successor are recorded under `integration/mc-sol01/drainage`.
