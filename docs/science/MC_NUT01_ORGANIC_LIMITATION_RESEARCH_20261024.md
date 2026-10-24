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

## Executable path-limited successor

**Proposed physical model, tested outside the production path.** The successor
`mod_path_limited_organic.f90` now implements a continuous limitation for the
same single-FOM/biomass topology. While NH4 is positive, it calls the unchanged
production analytic turnover and carbon routines. It locates the first N-zero
event across the full trajectory, including an interior demand maximum hidden
by a positive full-window net mineralisation.

At zero NH4 only the N-consuming FOM pathway slows. Biomass mineralisation
continues and supplies it. With \(c=0.039\), boundary activity is
\(\min(1,0.08 k_B B/(c k_F F))\). On that boundary
\(dB/dt=0.001 k_B B/c\) and \(dF/dt=-0.08 k_B B/c\).
This topology permits an exact constrained segment. When mineral release
catches the full FOM demand, production kinetics resume. No biomass or no
biomass turnover means no mineral release and a stalled boundary. This is an
explicit proposed allocation rule, not a recovered historical identity or an
accepted priority between crop, top and organic sinks.

The final candidate passes through the actual production pool owner. Carbon
losses are computed for the same constrained organic trajectory. The interface
returns its input pools and zero carbon flux for rejected candidates. Its
bounded input domain is documented in `PATH_LIMITED_CONTRACT.md`.

Fresh O0/O2 builds each compile three production providers, the research module
and its driver. An independent DOP853 differential-equation model checks96
configurations per optimization. The cases include zero NH4, zero biomass,
zero biomass turnover, equal rates and one/ten-day windows:

| Measured quantity | Maximum error or count per optimization |
| --- | --- |
| Endpoint disagreement with independent ODE | 1.48e-13 |
| Depletion/release-time disagreement, days | 3.25e-12 |
| Whole N budget residual, kg/m2 | 6.94e-18 |
| Whole C budget residual, kg/m2 | 1.92e-14 |
| Split-window continuation disagreement | 4.45e-14 |
| Depletion cases | 54 |
| Later release from the constraint | 11 |
| Stalled cases | 30 |
| Unlimited cases | 42 |

For the PR1429 counterexample with initial NH4=0.005, depletion occurs at
day0.0142803744011. The constrained day-end has FOM0.175463861895,
biomass0.0728067017263, effectively zero NH4 and carbon loss0.338278246370.
It follows a nonnegative N trajectory instead of jumping to a later endpoint
behind an infeasible mineral deficit.

`PATH_LIMITED_RESULT.json` binds the exact tested sources and
`PATH_LIMITED_EVIDENCE.tar.xz.b64` contains commands, stdout/stderr, results
and member hashes. Compile/link/native cost is approximately2.04s; independent
ODE validation costs2.85s. Replay with
`python integration/mc-nut01/competing_sinks/run_path_limited_organic.py --replay`.
The replay also rejects five numerical corruptions. Earlier rounds, including
an incorrect test expectation corrected before final qualification, are kept
in `PATH_LIMITED_EARLIER_ROUNDS.tar.xz.b64`.

The canonical delta since PR1429 contains the independently admitted BBC/Cauchy
and PERF01 work. The current source gate is reached through
`verify_saturated_picard_current.py`, which delegates to its current Cauchy
successor. Calling the old nonjuvenile source gate directly correctly rejects
that newer source envelope; it is no longer the current entry point. The
PR1429 source-bound numerical replay still passes, and all three production
providers used here remain exactly unchanged.

This resolves the numerical feasibility of one concrete limitation proposal.
It does not provide multiple FOM pools, humus turnover, NO3 access, crop/top
competition or carbon/denitrification feedback. Continuation was tested as a
physical state split, not a persisted runtime restart. Those compositions and
scientific selection of the extended allocation rule remain required before
production activation. Existing production sources and defaults are unchanged.

## Multi-pool executable successor

**Proposed research model outside production.** `mod_multipool_limited_organic.f90`
extends the experiment to multiple FOM pools, biomass and humus using the
original donor rates and assimilation fractions. The tested configurations
have two FOM pools. Stoichiometry determines which donor pathways release N
and which consume it. Thus FOM may mineralise, while humus or biomass may
immobilise. All consuming pathways share the same limiting activity when
mineral N runs out; releasing pathways continue at full activity. This is an
explicit research assumption about organic pathways. It does not establish
their priority relative to crop uptake or prescribed boundary sinks.

The native implementation uses positivity-preserving SSPRK2 stages and step
doubling. Each Euler stage caps consuming activity by its available NH4 plus
simultaneous mineral release. A donor-rate timestep cap prevents negative
organic pools. Convex RK combinations preserve positivity and the linear C/N
invariants; the accepted state uses two half steps without extrapolation.
The final candidate is checked by the production inventory owner. Nitrate is
unchanged and carbon fraction is uniformly0.45. Arithmetic domain and failure
limits are explicit in `MULTIPOOL_CONTRACT.md`.

Fresh O0/O2 each execute96 configurations at three tolerances, giving288
whole-window results plus split-state continuations. The matrix contains48
single-FOM configurations checked against PR1430's exact constrained solution,
and48 two-FOM/biomass/humus configurations. A separately assembled event-driven
DOP853 ODE checks every endpoint and locates53 depletion/release events.
At the finest setting64 configurations use the limitation. Invalid-tolerance
calls return every input pool exactly and zero carbon flux.

| Relative tolerance | Maximum absolute endpoint error |
| --- | --- |
| 1e-5 | 6.15e-6 |
| 1e-7 | 3.83e-7 |
| 1e-9 | 2.70e-8 |

Errors are compared componentwise in each printed native unit: organic pools
in kg/m3, NH4 and cumulative carbon in kg/m2. The table's maximum is a scoped
numerical diagnostic, not a universal error bound from the relative tolerance.
Both optimizations show the same convergence. Maximum whole N residual is
1.02e-15 kg/m2 and whole C residual6.72e-15 kg/m2. Finest-setting split-state
continuation differs by at most9.91e-9 in the corresponding native component.
O0/O2 endpoint differences are at most5.12e-12; their adaptive step counts
need not be identical. This is not bit-exact disk/runtime restart evidence.

`MULTIPOOL_RESULT.json` and `MULTIPOOL_EVIDENCE.tar.xz.b64` bind sources,
compiler/commands, native outputs, independent validation and measured costs.
Replay with `python integration/mc-nut01/competing_sinks/run_multipool_limited.py --replay`;
four numerical corruption controls exercise positivity, both budgets and
continuation assertions. `MULTIPOOL_EARLIER_ROUND.tar.xz.b64` retains an earlier
cross-optimization assertion failure: both native/ODE validations passed, but
an extra1e-12 equality bound was too tight for differing adaptive decisions.
Current qualification instead requires convergence, independent error bounds
and a separately stated1e-10 optimization comparison. Budget tolerances were
not relaxed.

This adds an executable multi-pool organic limitation proposal. Production
sources/interfaces/defaults and earlier proof capsules are unchanged. Crop/top
sharing, nitrate access, denitrification feedback and the complete runtime
commit/restart composition remain outside this research contract. The proposal
therefore does not close or activate full MC-NUT01.

## Proposed organic-first daily composition

The research successor `mod_organic_first_day.f90` now connects the multi-pool
candidate to the actual production reaction-rate, storage, daily exchange and
final pool-owner interfaces. It advances the organic suboperator first, uses
its constrained carbon receipt for denitrification feedback, then advances
mineral exchange from those organic/mineral endpoints with a zero additional
mineralisation source. This prevents double counting. The mineral suboperator
includes the admitted juvenile NH4-first crop demand and proportional crop/top
sharing. The final owner closes the complete daily N budget against the
original committed state. Any later failure returns that entire original state.

This is explicitly a proposed operator split over one physical day. It grants
organic pathways first access to initial NH4 and postpones mineral boundary
input until the mineral suboperator. It is neither simultaneous kinetics nor
historical equivalence. Different allocation/order choices need their own
scientific assessment; numerical closure does not select among them.

Fresh checked O0/O2 builds each compile14 sources, including11 unchanged
production providers. Twenty-four initial configurations each run six successive
days, producing144 endpoint/ledger rows per optimization. Cases vary NH4,
NO3, crop demand and chemical activation. An independent event-driven organic
ODE followed by independently integrated mineral ODEs checks every organic and
mineral endpoint, constrained carbon, reaction rates, nitrification/gas loss,
crop uptake and actual/unmet top receipts. Nitrification input to NO3 uses the
same daily-average-source convention as the admitted mineral contract. The
fixture has constant water storage and no roots/lateral/bottom transport; it
does not qualify a water/Richards composition.

Maximum endpoint/receipt discrepancy is2.03e-8 in the respective printed native
component, whole N residual2.26e-15 kg/m2 and whole C residual1.24e-15 kg/m2.
Each optimization contains39 gas-producing days and101 top-limited days.
An invalid temperature injected after completed organic work on every day
rejects at the rate seam and returns all input pools exactly. Partial organic
receipts remain diagnostic, not accepted effects. This is144 late-rejection
comparisons per optimization; no persisted runtime checkpoint is claimed.

`ORGANIC_FIRST_DAY_CONTRACT.md`, `ORGANIC_FIRST_DAY_RESULT.json` and the sealed
`ORGANIC_FIRST_DAY_EVIDENCE.tar.xz.b64` own the source-bound result. Replay with
`python integration/mc-nut01/competing_sinks/run_organic_first_day.py --replay`.
Four numerical corruption controls are included. Compile/link/native costs
approximately3.64s and independent validation1.99s. An earlier mineral-oracle
failure at a negative roundoff residue on the zero-N boundary is retained in
`ORGANIC_FIRST_DAY_EARLIER_ROUND.tar.xz.b64`; the corrected oracle rejects any
real deficit before normalising bounded boundary roundoff. Production/numerical
Fortran code did not change in that correction.

The daily composition is implemented and tested as executable research. The
existing production route/defaults, prior capsules and owning guards are
unchanged. Production activation, scientific selection of daily allocation,
general forcing/root/nonjuvenile coverage, persisted runtime restart, snow
and full MC-NUT01 remain open.
