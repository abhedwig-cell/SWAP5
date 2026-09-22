# Fixed-interface coupling globalization research plan

Date: 2026-09-21
Status: PREREGISTERED NEXT PHASE

## Question

Given a physical outward SWAP response q(H) with local derivative p=dq/dH and a groundwater residual R(H), which linearization/globalization closes the fixed-interface equation robustly without changing accepted physical exchange semantics?

## Frozen semantics

- H is hydraulic head at the fixed geometric coupling plane.
- q>0 is SWAP -> groundwater.
- accepted mass is the final physical SWAP corrector exchange, never the affine working surrogate.
- physical storage inventories remain disjoint.
- rejected corrector trials have zero authority.

## Candidate numerical policies

P0 current surrogate:
  s=+u/dt, exact reanchor after every accepted trial.

P1 physical Newton tangent:
  s=dq/dH, using -u/dt only where independently qualified as that derivative.

P2 Picard:
  s=0, exact reanchor.

P3 relaxed current surrogate:
  compute raw P0 update, then H_{k+1}=H_k+alpha(H_raw-H_k), 0<alpha<=1.

P4 safeguarded physical tangent:
  P1 inside the admissible corrector envelope; reject/contract a proposed head step that lies outside the envelope.

No policy is production-admitted by this preregistration.

## Analytical qualification family

For a scalar groundwater storage response a=dq_gw/dH and locally affine physical SWAP response p=dq/dH, a reanchored surrogate slope s gives

  e_{k+1} = rho e_k,
  rho = (p-s)/(a-s)

under the sign convention q_swap=q_gw.

A relaxed update gives

  rho_alpha = 1-alpha+alpha*rho.

Qualification:
- fixed-point consistency is necessary but not sufficient;
- local contraction requires |rho|<1;
- relaxed contraction requires |rho_alpha|<1;
- a physical Newton slope s=p gives rho=0 for the affine local problem, provided the groundwater denominator is nonsingular;
- trial-envelope admissibility is an independent gate.

## Prospective experiments

G01: reproduce NH01/PB01 for P0-P3 and compare measured versus derived rho.
G02: sweep groundwater storage response a while holding SWAP p fixed; locate singular and unstable regions without post-hoc policy tuning.
G03: sweep p/a ratio and derive policy phase diagram.
G04: nonlinear NH03 response: compare Newton, Picard, positive surrogate and safeguarded Newton from multiple preregistered starts.
G05: real F-GC44 corrector: use only admissible head perturbations; estimate p prospectively and test one-step local predictions without committing rejected states.
G06: asymmetric admissibility: test step contraction/safeguard independently of residual convergence.
G07: only after G01-G06, evaluate whether a general production algorithm can be admitted.

## Decision gate

A production algorithm must separately satisfy:
1. physical fixed-point correctness;
2. mass/transaction authority;
3. local convergence;
4. finite perturbation robustness within declared envelope;
5. behavior at/near singular response ratios;
6. no dependence on undocumented MODFLOW solver stabilization.


## G03-LIVE / G05 / G06 concrete protocol (2026-09-21)

This section freezes the live F-GC44 instantiation before reading its result.

G03-LIVE identifies the effective local MODFLOW response with constant-flux API
probes, not with a moving affine intercept. Each probe uses HCOF=0, prescribes
q_gw in {-4e-8,-2e-8,-1e-8,+1e-8,+2e-8,+4e-8} m/s, starts from a fresh copy of
the F-GC44 MODFLOW model and the same accepted XOLD, and iterates MODFLOW to its
own convergence before recording (H,q_gw). The fitted a=dq_gw/dH is therefore
an intrinsic groundwater response over the sampled local head range.

Finite real-SWAP starts are fixed prospectively at
{-1e-6,-5e-7,+5e-7,+1e-6,+2e-6} m relative to href.

The earlier interpretation of the first -2e-6 m local-scan result is withdrawn
before the replacement G06 run. Source inspection shows participant status 4 is
CANDIDATE_BUSY. The historical test left trial(href) live before the first scan
point, so that point did not execute the corrector and cannot define a head
admissibility boundary.

Replacement G06 first reproduces that status-4 ordering artifact explicitly.
It then evaluates the cold-process head grid
{-1e-4,-5e-5,-2e-5,-1e-5,-5e-6,-2e-6,-1e-6,
 +1e-6,+2e-6,+5e-6,+1e-5,+2e-5,+5e-5,+1e-4} m relative to href.
Every point runs in a fresh process from the same accepted physical origin.
Only participant status 6 (TRIAL_FAILED) counts as a corrector failure.
Status 4 is forbidden in the clean scan.

If one or more status-6 points occur, G06 selects the failure with the smallest
absolute head perturbation, breaking ties toward the negative perturbation, and
applies fixed factor-1/2 contractions toward href for at most 12 contractions.
If no status-6 point occurs in the fixed grid, G06 records that the safeguard
trigger was not exercised and makes no broader envelope claim.

P3 does not tune alpha from finite-start trajectories. It uses
alpha*=1/(1-rho_P0), computed once from frozen real-SWAP p and the prospectively
measured G03-LIVE a, provided 0<alpha*<=1.

P4 uses physical-tangent reanchoring plus a fixed factor-1/2 head-step
contraction whenever a proposed SWAP corrector head is inadmissible. Rejected
trials are discarded and have zero mass/state authority.

All G03-LIVE/G05/G06 runs are diagnostic. They must leave SWAP revision, time,
ledger count and committed interface exchange at the immutable accepted origin.
No production HCOF/RHS source is changed by these experiments.


## Execution checkpoint: G03-LIVE/G05/G06

Tested commit: `81f7e00ad7d6fc9509800c4cb9ecc03d99faef4e`  
Workflow run: `35618874403`  
Result: PASS

The result is persisted in
`integration/research/GC_FIXED_INTERFACE_FGC44_GLOBALIZATION_G03_RESULT.json`.
The status-4 historical point is classified as CANDIDATE_BUSY and is not used
as admissibility evidence. The replacement cold-process scan and safeguard
test passed under the protocol above.


## G04 concrete nonlinear protocol

G04 uses the already derived NH03 nonlinear-storage oracle without changing its
physical parameters. The coupled scalar is y=Hc1-Hc0 and the exact root remains
y*=0.03460974498448890 m.

The positive-surrogate policy P0 freezes the production-style predictor
magnitude at the preregistered qb=0 predictor,
s=+0.09282032302755092. P1 recomputes the exact physical response derivative
p(y) at each iterate. P2 uses s=0. P3 retains the frozen positive surrogate but
computes alpha(y)=1/(1-rho(y)) from the exact local NH03 physical derivative,
without trajectory tuning. P4 uses P1 with factor-1/2 step contraction until
the proposed point is on the physical branch and does not increase the absolute
coupled residual.

The fixed starts are
{-0.23,-0.10,-0.02,0.0,+0.02,+0.06,+0.10,+0.30} m in y.
The convergence tolerance is 1e-12 m and the outer budget is 250. P4 has a
maximum of 20 factor-1/2 contractions per outer update.

Prospective questions are:
1. whether frozen positive P0 remains robust under deliberate nonlinearity;
2. whether physical Newton converges from all starts;
3. whether Picard remains a slower but contractive baseline;
4. whether response-derived P3 is algebraically equivalent to Newton when the
   exact physical derivative is available;
5. whether P4 prevents the large Newton excursion from the difficult -0.23 m
   start without changing the accepted root.


### G04 P3 admissibility clarification after first execution

The first G04 execution exposed a prospective policy-boundary case rather than a
numerical implementation failure: at the fixed difficult start y=-0.23 m the
derived alpha(y)=1/(1-rho(y)) is greater than 1. The frozen P3 definition
requires 0<alpha<=1. Therefore the rerun classifies such a point as
RELAXATION_NOT_ADMISSIBLE. It does not clip alpha to 1, tune alpha, remove the
start, or convert the case into convergence evidence. P3/Newton equivalence is
tested only at starts where the preregistered P3 relaxation range is satisfied.


## Execution checkpoint: G04 nonlinear NH03

Tested commit: `4fc42812abdd893785ca408b6bc5803d56f724a1`  
Workflow run: `35619773763`  
Result: PASS

P0 is inadmissible from all eight frozen starts. P1 converges from all starts
but reaches `|y|=19.0598 m` from the difficult `y=-0.23 m` start. P2 converges
from all starts in 160 to 173 outer iterations. P3 is not an admissible
under-relaxation at `y=-0.23 m` because its derived alpha is 3.8650; for the
other seven starts it is algebraically equivalent to P1 and converges. P4
converges from all starts and uses six half-step contractions at the difficult
start, keeping `max|y|=0.23 m`.

The result is persisted in
`integration/research/GC_FIXED_INTERFACE_GLOBALIZATION_G04_RESULT.json`.


## G07A live groundwater-regime transition protocol

G07A is preregistered before execution as a live bridge from the analytical G02
phase map to the concrete F-GC44 Richards corrector. It does not change SWAP,
MODFLOW production source, or the frozen real-SWAP local derivative.

The SWAP window remains 1e-4 day and uses the already qualified F-GC44
`p=dq_swap/dH` and `s0=+u/dt`. MODFLOW uses the same 1x1x3 geometry and CHD
heads but suppresses lateral response with `K=1e-10 m/day`, sets `ss=0`,
and varies unconfined `sy` prospectively as

```text
sy = r_target * u
r_target in {0.5, 1.2, 2.0, 4.0}.
```

This construction is chosen from the storage-dominated relation
`a approximately sy/dt`; the realized `a=dq_gw/dH` is nevertheless measured
independently with fresh, converged constant-flux MODFLOW probes before any
policy result is interpreted. Realized `r=a/|p|` must remain within 0.2% of
the target.

For each realized regime a physical-tangent P1 solve defines the diagnostic
reference root. P0, P1 and P2 then receive one fixed `+1e-7 m` root-relative
perturbation. P3 uses only
`alpha*=1/(1-rho_P0)`; if that value is outside `0<alpha<=1`, the policy is
classified `RELAXATION_NOT_ADMISSIBLE` rather than clipped or tuned.

Prospective class expectations follow G02 exactly:

- `r<1`: P0 divergent, P2 divergent, P1 locally exact, no admissible positive
  P3 cancellation;
- `1<r<3`: P0 divergent, P2 contractive, P1 locally exact, P3 contractive;
- `r>3`: P0, P2 and P3 contractive; P1 locally exact.

Measured one-step amplification must match the analytical rho to absolute
tolerance 2e-3. Candidate corrector status is recorded separately from outer-map
contraction so that head inadmissibility is never relabelled as divergence.


## Execution checkpoint: G07A live phase transitions

Tested commit: `7f228f5ed2093d942e1312e7c522638e12b3a029`  
Workflow run: `35620324752`  
Result: PASS

Realized response ratios were 0.5000007, 1.2000017, 2.0000028 and 4.0000057.
The measured one-step factors matched G02 in every policy/regime combination.
The machine-readable result is
`integration/research/GC_FIXED_INTERFACE_FGC44_G07A_RESULT.json`.

G07 production admission remains negative at this checkpoint. P4 is retained
as the leading research candidate; no production source is changed.


## G08 real-SWAP safeguarded physical-Newton protocol

G08 is preregistered in machine-readable form at
`integration/research/GC_FIXED_INTERFACE_G08_PREREGISTRATION.json`.
It is a production-candidate research qualification, not a production mutation.

The frozen real-SWAP cases are the F-GC44 control plus low-forcing,
high-forcing and long-window/high-forcing READY points already identified by
the independent DSW22D predictor-envelope diagnostic. The known 5e-5 day
predictor failure remains excluded as a preserved upstream falsification; G08
does not retune it into a corrector case.

For each selected SWAP configuration G08:

1. scans the fixed head offsets declared in the JSON preregistration and records
   status-0 versus status-6 corrector outcomes;
2. re-estimates the physical `dq_swap/dH` by a central secant from the immutable
   accepted origin, with a fixed 2.5e-7 m half-width and at most six halvings;
3. classifies material real-SWAP nonlinearity only if the maximum admissible
   secant-slope change from the href tangent reaches the prospectively frozen
   5% threshold;
4. measures each groundwater response independently with fresh converged
   constant-flux MODFLOW6 probes;
5. compares raw physical Newton (P1) against P4, which uses the same reanchored
   physical tangent but contracts the head proposal by exactly 1/2 until the
   SWAP corrector is admissible and the independently measured coupled-residual
   magnitude does not increase.

The three groundwater classes are a storage-dominated `r≈0.75` construction,
a storage-dominated `r≈2` construction, and the ordinary mixed
storage/lateral-conductance model. Before execution, the two storage-dominated
cases were amended with fixed accepted-groundwater head mismatches of +4e-6 m
and -1.5e-6 m respectively. This forces the Newton proposal to traverse a
nontrivial fraction of the real-SWAP head envelope without changing SWAP
physics, solver tolerances or acceptance rules.

Every diagnostic SWAP candidate is discarded. Revision, committed time and
interface ledger must remain at the accepted origin. Status 4 remains a
lifecycle error rather than admissibility evidence. No production HCOF/RHS
source is changed.

The interpretation rules are deliberately asymmetric:

- a completed G08 workflow proves execution of the frozen experiment, not
  production admission;
- if no real-SWAP case reaches the 5% nonlinearity threshold, genuinely
  nonlinear real-SWAP qualification remains open;
- if P4 performs no backtracking, the live safeguard remains unexercised;
- the strongest G08 evidence is a preregistered case where raw P1 is
  inadmissible or merit-increasing and P4 contracts to an admissible,
  non-increasing step;
- any production algorithm or HCOF/RHS mutation requires a separate admission
  work unit after G08.


## G09 boundary tangent acquisition protocol

G09 addresses the concrete failure mode exposed by G08: a valid real-SWAP
trial can lie on a one-sided corrector admissibility boundary where a symmetric
central secant cannot be formed.

The machine-readable preregistration is
`integration/research/GC_FIXED_INTERFACE_G09_PREREGISTRATION.json`.

Two estimators are frozen before execution:

- **E0** retains the G08 central secant and serves as the baseline;
- **E1** starts with the same symmetric probes. If exactly one side is
  admissible, it infers the admissible direction only from the trial statuses,
  takes a second probe at twice that spacing in the same direction, and applies
  the fixed second-order three-point one-sided derivative formula. If neither
  construction is available it halves the spacing, up to the same bounded
  budget.

Every probe is evaluated from the immutable accepted SWAP origin and discarded.
No rejected probe has state or mass authority.

The eight frozen head states are the negative and positive extreme admissible
points observed in the four G08 SWAP cases. The critical targeted replay is the
C2 high-forcing negative state at `dh=-5e-6 m`, where G08 produced all six
`TANGENT_UNAVAILABLE` policy outcomes. G09 first requires E0 to reproduce that
failure and E1 to recover a finite negative tangent with a prospectively frozen
5% half-step consistency bound. It then replays P1 and P4 with E1 across the
same three G08 groundwater regimes.

G09 does not require safeguard contraction. Its question is narrower: whether
physical tangent acquisition itself can be made admissibility-aware without
hard-coded direction or transaction leakage. Production admission remains out
of scope.
