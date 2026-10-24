# MC-NUT01 organic limitation investigation, 24 October 2026

**Research result, not a new physical option or production admission.**
Baseline is canonical `43ee311ae4b525afd191a8e38c66a17d9c8b3a17`, following
PR1427. Production sources, interfaces, defaults and earlier qualifications
are unchanged. The remaining organic limitation requires a physical allocation
contract that determines the organic pools and carbon flux together with N.

## Current and historical contracts

The daily candidate first computes analytic FOM, biomass and humus endpoints.
Their exact organic N difference determines the signed mineralisation transfer.
Carbon dissimilation then determines the reaction-rate environment. The mineral
exchange is composed with those organic endpoints, and the pool owner verifies
the complete N budget before acceptance. Reducing the mineral debit while
leaving the organic N increase intact violates this budget.

The immutable historical `SWAP/wofost_soil_orgmatn.f90` calculates organic pools
and Nminer before `SWAP/management_soil.f90` passes Nminer/dt to WaterN. These
sources do not specify how an unmet immobilisation receipt changes organic
endpoints. Their original repeated FOM-to-biomass N term is a previously known
reference correction; it is not the oracle for this investigation. Original
source identities are retained in the result, independently of the current
pool-difference calculation.

Existing sufficient-stock organic immobilisation already works. The new direct
driver confirms it through the real daily candidate in both historical and
signed-top modes. Insufficient stock returns the exact input candidate, and
the proportional option continues to exclude negative net mineralisation.
These are candidate/pool-owner checks, not a new runtime restart qualification.

## Why a scalar kinetic bound is insufficient

A deliberately simple research system uses one FOM pool with initial mass1,
zero biomass/humus, FOM decomposition10/day, biomass decomposition5/day and
50% FOM-to-biomass assimilation. Biomass decomposition has no assimilation.
Depth is1m, N fractions are0.001/0.08/0.02 and C fractions are all0.45.
These fast coefficients expose a mathematical boundary; they are not a field
calibration or a claim about the frequency of this regime in production.

Multiplying every kinetic rate by activity \(a\) gives the independent solution

\[
F(a)=e^{-10a},\qquad B(a)=e^{-5a}-e^{-10a},\qquad H(a)=0,
\]

and organic N gain

\[
I(a)=0.08e^{-5a}-0.079e^{-10a}-0.001.
\]

The production analytic turnover, N transfer and carbon routines agree with
this independent solution at2001 activities per optimization. Maximum absolute
error is3.39e-15. For mineral stock0.005 kg N/m2, two equality endpoints exist:

| Activity | Organic N gain, kg/m2 | Carbon dissimilation, kg/m2 |
| --- | --- | --- |
| 0.0142803744011 | 0.005 | 0.0310105625062 |
| 0.501257302247 | 0.005 | 0.413293234962 |

Both endpoint transfers conserve N. The later endpoint passes through organic
N demand above the initial stock: the maximum demand is approximately0.0192532
kg/m2. Full activity has net mineralisation, approximately0.000464551 kg/m2.
Thus endpoint feasibility is not monotone in activity, and daily net exchange
alone cannot choose a physically accessible kinetic history. This does not
invalidate the admitted daily-average source approximation. It rules out
treating a global activity bisection as a justified generic limitation policy.

At activity0.13, clipping the mineral debit to0.005 without changing the
organic pools creates0.0142336504912 kg N/m2. The real pool owner rejects this
transfer with `SOIL_N_BALANCE` and returns every input pool exactly.

## Evidence and next implementation boundary

The existing competing-sinks work unit owns the executable contract,
`run_organic_constraint.py`, `test_organic_constraint.f90`, sealed
`ORGANIC_CONSTRAINT_EVIDENCE.tar.xz.b64` and `ORGANIC_CONSTRAINT_RESULT.json`.
`verify_organic_constraint.py` replays every analytic assertion, checks source
and raw-member identities, and rejects11 deliberate corruptions. Each O0/O2
build freshly compiles11 production providers plus the driver, and runs2001
activity points, six daily candidates, two conservative root transfers and
one deliberately incorrect clipped transfer. Raw commands, stdout/stderr,
compiler identity and measured costs are retained in the capsule.

Reproduce with `FC=/path/to/gfortran python integration/mc-nut01/competing_sinks/run_organic_constraint.py --out /absolute/new/output-directory`.
Replay with `python integration/mc-nut01/competing_sinks/verify_organic_constraint.py`.

A production extension must select the N-limited organic kinetics and the
priority between immobilisation, crop and top sinks; state which mineral forms
can supply immobilisation; compute carbon and reaction feedback consistently;
and qualify the complete C/N balance, rejection and restart composition. A
trajectory-aware limitation can be researched next, but is not inferred from
the current equal-priority mineral partition. Automatic snow/surface N and full
MC-NUT01 remain open. Existing PR1427 admission is unchanged.
