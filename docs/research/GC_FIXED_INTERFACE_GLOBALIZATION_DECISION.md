# Fixed-interface globalization decision after G07A

Date: 2026-09-21  
Status: RESEARCH DECISION; NO PRODUCTION ADMISSION

## Evidence combined

The decision now uses four distinct evidence classes rather than one successful
coupled fixture.

- G01/G02 give the local phase map.
- G03/G05 place the ordinary F-GC44 fixture at `r≈5170.76` and verify finite
  real-SWAP/MODFLOW amplification factors.
- G06 separates true corrector failure from candidate-lifecycle errors and
  demonstrates factor-1/2 admissibility recovery.
- G04 supplies deliberate nonlinear response evidence.
- G07A reproduces the G02 phase transitions with live MODFLOW and the real
  F-GC44 corrector at realized `r≈0.5, 1.2, 2.0, 4.0`.

## Policy disposition

### P0 current positive surrogate

Not generally admissible.

The live G07A sweep gives:

```text
r≈0.5  -> rho≈+4.0   divergent
r≈1.2  -> rho≈-10.0  divergent
r≈2.0  -> rho≈-2.0   divergent
r≈4.0  -> rho≈-0.667 contractive
```

The ordinary F-GC44 configuration at `r≈5170.76` is therefore a valid stable
regime, not evidence of universal stability. PB01 and G07A provide live
counter-regimes.

### P2 Picard

Useful baseline, not a universal production policy.

G07A confirms divergence below `r=1` and contraction above `r=1`. G04 shows
that Picard can also be robust under nonlinearity, but at a high iteration cost.

### P3 relaxed positive surrogate

Principled only in a bounded regime.

For `r<1` the response-derived cancellation alpha is negative, so positive
under-relaxation cannot repair the divergent P0 map. For `1<r` the linear
cancellation is valid, but G04 shows that nonlinear starts can require
`alpha>1`, outside the preregistered relaxation range. Where exact physical
`p` is known and alpha is admissible, the P3 update collapses algebraically to
the Newton step rather than providing an independent robustness mechanism.

### P1 physical Newton

Best local linearization, but insufficient unsafeguarded.

It is locally exact in G01/G02 and every live G03/G07A regime. G04 nevertheless
shows that an unsafeguarded nonlinear Newton step can make a hydrologically
unacceptable excursion by orders of magnitude before returning to the root.

### P4 safeguarded physical Newton

Leading research candidate.

It combines the locally correct physical tangent with an explicit admissibility
safeguard. G04 shows bounded nonlinear behavior where raw Newton excursions are
large, and G06 shows that factor-1/2 contraction can recover a real F-GC44
corrector failure without granting rejected trials physical or mass authority.

## Production gate

P4 is **not yet production-admitted**. The remaining gap is no longer the local
sign question or the scalar phase-map theory. It is qualification of a concrete
production algorithm that obtains or approximates the physical tangent over
real SWAP windows and process regimes, applies safeguarding without violating
the immutable-origin transaction contract, and is tested across materially
different groundwater storage/lateral-conductance settings and genuinely
nonlinear real-SWAP responses.

Therefore:

```text
DO NOT CHANGE PRODUCTION HCOF SIGN YET.
DO NOT ADMIT P0, P2 OR P3 AS UNIVERSAL FALLBACKS.
P4 = LEADING RESEARCH CANDIDATE, NOT PRODUCTION AUTHORITY.
```


## G08 disposition: safeguarded Newton over configured real-SWAP regimes

G08 executed the preregistered four-case real-SWAP matrix against three
independently measured MODFLOW response classes. The workflow execution,
transaction-authority checks and groundwater response oracles passed.

The result does **not** provide the missing production admission.

- none of the four SWAP cases reached the preregistered 5% material-nonlinearity
  threshold; the largest observed admissible secant-slope change was about
  1.94%;
- 21/24 P1 cases and 21/24 P4 cases converged;
- P4 performed zero factor-1/2 contractions, because no raw Newton proposal was
  inadmissible and no raw proposal increased the frozen coupled-residual merit;
- the remaining three starts for each policy all occurred at the C2
  high-forcing negative admissibility edge and stopped before proposal
  generation because the two-sided central tangent could not be obtained even
  after the preregistered probe-width halvings.

This is a useful negative result. It moves the unresolved production-candidate
question one level earlier in the algorithm:

> how is a trustworthy physical tangent obtained when the accepted real-SWAP
> trial lies on, or sufficiently close to, a one-sided corrector admissibility
> boundary?

The next bounded work unit is G09. It must compare the existing central secant
with an admissibility-aware tangent estimator that may use a one-sided or
asymmetric secant only when trial status demonstrates that the opposite probe is
unavailable. Rejected probes retain zero state and mass authority. The
estimator must be prospectively frozen before re-running P1/P4.

The production disposition therefore remains unchanged:

```text
NO PRODUCTION HCOF/RHS CHANGE.
P4 REMAINS A RESEARCH CANDIDATE.
G08 DID NOT EXERCISE THE SAFEGUARD.
CENTRAL TWO-SIDED TANGENT ACQUISITION IS NOT SUFFICIENT AT ALL REAL-SWAP BOUNDARY STATES.
```


## G09/G09A disposition: tangent acquisition is execution-topology dependent

G09 prospectively tested a status-driven central/one-sided physical tangent
estimator on the eight frozen G08 boundary states. Its broad qualification gate
was **falsified** in workflow `35699061533`.

The result has two distinct parts that must not be conflated:

- at the C2 high-forcing negative edge, the old central estimator remained
  unavailable while the preregistered one-sided fallback immediately produced
  a stable negative tangent. This is bounded positive evidence for that one
  state;
- the all-boundary 5% scale-consistency gate nevertheless failed at the
  C3 long-window positive edge. G09 therefore remains failed.

G09A then froze two states and nine probe scales to diagnose the mechanisms
without changing the G09 tolerance or estimator.

### C2 negative: fragmented numerical admissibility

The participant validity pattern changes repeatedly with decreasing probe
distance. Every sampled participant failure is reproduced in the raw corrector
as an incomplete `result_status=2` solve with repeated solver rejections.
The pattern is therefore numerical/component-domain topology, not evidence of
a discontinuous hydrological response.

Where negative-side probes are admitted, their accepted execution signature
matches the center and their one-sided slope is stable near
`-3.97158e-6 s^-1`.

### C3 positive: admitted probes can still cross an execution branch

All G09A C3-positive probes are participant-status 0. The large positive
probes, however, switch from the center's one-substep/no-retry execution to a
two-substep route with one temporal rejection/retry. Finite differences that
span that switch give strongly scale-dependent slopes.

Once the stencil remains inside the same accepted execution topology as the
center, central, one-sided and local-regression slopes collapse near
`-3.81275e-6 s^-1`.

This means participant admissibility alone is not enough to define a local
physical-response derivative of the executed corrector. A probe can be valid
yet belong to a different numerical execution branch.

## G09B candidate rule

G09B is preregistered as a new estimator, not a repair of G09. A derivative
probe may contribute only when:

1. participant status is 0;
2. the raw trial is complete and candidate-ready; and
3. accepted substeps, attempts, retries, solver rejections, temporal
   rejections and internal retries exactly match the current center trial.

Central differencing remains preferred when both sides satisfy that rule.
Otherwise a fixed second-order one-sided formula is allowed only on a side
whose first two probes share the center execution topology. The same 5%
half-scale consistency gate is retained.

No production change follows from G09, G09A or G09B. Even if G09B qualifies,
cost, broader process coverage and genuinely nonlinear real-SWAP behavior
remain separate production gates.


## G09B disposition: exact execution-signature matching is too strict

G09B prospectively required every finite-difference probe to be participant
status 0 and to match the current center trial exactly in accepted substeps,
attempts, retries, solver rejections, temporal rejections and internal retries.

The all-boundary gate was falsified in workflow `35700067828` at the
`C1_LOW_FORCING` negative boundary state (`dh=-5e-6 m`). The test stopped
before the preregistered C2/C3 P1-E2/P4-E2 policy replays, so no policy
qualification follows from G09B.

This failure does not undo the G09A diagnosis. It sharpens it:

- participant status alone is too weak because admitted probes can cross a
  temporal-substep route change;
- exact equality of the complete retry/attempt signature is too strong because
  it can eliminate every bounded derivative stencil at an otherwise admitted
  state.

G09C therefore freezes the C1-negative failure and a G09B-qualified C0-positive
control over the same nine-scale ladder. It decomposes the execution signature
field by field and records status-only slope plateaus without changing G09B.

The production disposition remains unchanged:

```text
G09B = FALSIFIED AS A UNIVERSAL TANGENT ESTIMATOR.
DO NOT WEAKEN ITS SIGNATURE RULE RETROSPECTIVELY.
NO PRODUCTION HCOF/RHS OR COUPLING CHANGE.
NEXT: IDENTIFY THE MINIMUM EXECUTION-CLASS CONTRACT FROM G09C EVIDENCE.
```


## G10/G10A disposition: nonlinear carrier qualified, broad groundwater merit falsified

G10 bound the live configured real-SWAP carrier exactly to frozen E4 baseline
B4: `dt=0.01 d`, `qbot=1e-6 cm/d`,
`href=-0.7149999311459918 m`, and
`u_A=0.00119027208545508`. That binding passed.

The B4 carrier also passed the prospectively frozen real-SWAP nonlinearity
gate. E3 changed from about `-1.37763e-6 s^-1` at the reference head to
about `-1.61834e-6 s^-1` at `dh=+1e-5 m`, a relative change of about
17.47%.

G10 itself nevertheless remains **falsified**. In the mixed groundwater regime
the negative-start raw Newton path reached a status-0 candidate, but the broad
affine groundwater merit classified the second Newton proposal as worse.
P1 then exhausted its outer budget and P4 exhausted all 12 factor-1/2
contractions.

G10A diagnosed that failure without changing E3, P4, tolerances or starts. The
broad mixed-groundwater response had a maximum fit error of
`2.54919e-13 m/s`, about 255 times the G10 coupled-residual tolerance.
Locally, fixed near-zero-flux fits reduced that error to approximately
`1e-19 m/s`.

Most importantly, direct MODFLOW inversion gives:

- at the G10 outer-1 accepted head, direct coupled residual about
  `5.06e-14 m/s`;
- at the raw outer-2 Newton proposal, direct coupled residual about
  `2.17e-16 m/s`;
- direct coupled root head `-0.7149997332230622 m`.

The broad-affine reference root was displaced by about `1.808e-9 m`.
The broad merit therefore rejected a raw Newton proposal that was already
essentially at the direct physical coupled root.

The interpretation is intentionally asymmetric:

- G10 stays failed under its preregistered broad-affine merit contract;
- the G10 failure is **not** evidence that E3 physical Newton or P4 is
  intrinsically unstable on B4;
- the broad affine groundwater response is not an adequate merit/root oracle at
  a `1e-15 m/s` convergence scale for this mixed regime;
- a direct-groundwater-merit replay may be qualified separately, but may not
  retroactively turn G10 into PASS;
- genuine live safeguard recovery from a physically bad Newton proposal remains
  open.

No production HCOF/RHS or coupling policy change is authorized.


## G10B disposition: local groundwater merit removes the G10 false rejection

G10B replayed the frozen B4/GW_MIXED path with only the groundwater
merit/reference oracle changed to the prospectively frozen 13-point local
response selected from G10A. E3, both +/-1e-5 m starts, the P4 factor-1/2
backtracking rule, outer budget and convergence tolerances were unchanged.

The local MODFLOW response fit had a maximum error of
`3.20875e-19 m/s`, well below the unchanged `1e-15 m/s` coupling scale.
Its coupled reference root was `-0.7149997332272907 m`, only
`4.23e-12 m` from the independent G10A direct root.

Both P1-E3 and P4-E3 converged from both frozen starts in two outer updates.
The final residual was about `9.38e-21 m/s`. P4 used zero contractions and
encountered no inadmissible raw proposal.

Therefore G10 remains formally falsified under its original broad-affine
oracle, while G10B separately establishes that the B4/GW_MIXED physical Newton
path is well behaved when the groundwater merit is resolved at the requested
scale. The remaining unqualified question is narrower and more important:
whether P4 can recover a genuinely bad live physical-Newton proposal rather
than merely agree with P1.

No production HCOF/RHS or coupling-source change follows from G10B.


## G11 disposition: live P4 safeguard recovery is exercised

G11 prospectively constructed a storage-dominated B4/MODFLOW stress from
previously measured B4 and r≈0.5 response evidence. No SWAP solver tolerance,
retry budget, E3 tangent rule or P4 backtracking rule was changed.

The first physical-Newton proposal from the B4 reference head was
`dh=-1.1162302297e-5 m`, beyond the frozen `dh=-1e-5 m` negative edge. The
proposal failed with participant status 6.

The two policies then separate cleanly:

- **P1-E3** stops immediately with `RAW_PROPOSAL_INADMISSIBLE`;
- **P4-E3** starts from the identical raw proposal, performs two fixed
  factor-1/2 contractions, accepts `dh=-2.7905756e-6 m`, and subsequently
  converges in three outer updates to `dh=-9.9993468e-6 m`.

The final P4 residual is approximately `1.06e-20 m/s`. Every rejected or
diagnostic SWAP trial is discarded, so accepted revision, time and mass-ledger
authority remain unchanged.

This closes the specific research question whether the unchanged P4 safeguard
can recover a genuinely bad live physical-Newton step. It can, in the bounded
B4 stress case.

The production gate is nevertheless still closed. The unresolved questions are
now cost and implementation rather than local stability: E3 is a research
finite-difference reference estimator with multiple diagnostic trials, broader
process coverage remains incomplete, and no production tangent API or
production HCOF/RHS implementation has been admitted.

```text
G11 LIVE SAFEGUARD RECOVERY = QUALIFIED RESEARCH EVIDENCE.
E3 = REFERENCE TANGENT ESTIMATOR, NOT YET A PRODUCTION ALGORITHM.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: COST / TANGENT-ACQUISITION / PROCESS-COVERAGE QUALIFICATION.
```


## G11 disposition: live safeguard recovery qualified

G11 supplies the live recovery evidence that remained open after G10B.

The carrier is the frozen nonlinear B4 real-SWAP case and the tangent estimator
is the unchanged qualified E3 estimator from G09D. The groundwater stress was
preregistered before execution and used a storage-dominated response with an
independently measured affine fit error of only about
`3.71e-21 m/s`; no tangent degradation, SWAP tolerance change or retry-budget
change was used to manufacture the overshoot.

From the accepted B4 reference head, P1 and P4 generate the identical first raw
physical-Newton proposal:

```text
raw dh = -1.1162302297473836e-5 m
participant status = 6
```

The frozen negative target edge was `dh=-1e-5 m`, so the raw Newton proposal
overshoots the known admissible edge and is a genuinely bad live proposal.
P1 therefore terminates as `RAW_PROPOSAL_INADMISSIBLE`.

P4 applies the unchanged factor-1/2 safeguard. Two contractions recover an
admissible, merit-reducing first update. Subsequent E3 Newton updates converge
in three outer updates total to

```text
final dh       = -9.999346805233955e-6 m
final residual = -1.0640987109201395e-20 m/s
```

All diagnostic SWAP candidates remain trial-only and are discarded; committed
revision, committed time and interface ledger authority remain unchanged.

This closes a specific research gap:

- a real nonlinear SWAP carrier can generate a physically consistent Newton
  overshoot;
- the same P4 safeguard that was only analytical in G04 and admissibility-only
  in G06 now recovers that live proposal;
- G10's earlier safeguard exhaustion remains falsified under its original
  broad groundwater oracle and is not retroactively relabelled.

The result is still **not production admission**. Broader real-SWAP process
coverage and the computational/integration contract for obtaining E3 remain
open before any production HCOF/RHS change.


## G12/G12A disposition: active-drainage tangent evidence survives, groundwater anchoring gate does not

G12 extended the E3/P4 research line to the frozen MAP09 active-drainage
prescribed-head corrector. The SWAP-side evidence is positive but the complete
G12 gate is **falsified**.

Before the failing groundwater gate, G12 qualified:

- E3_MAP at MAP09 href and both frozen `dh=±1e-6 m` starts;
- href slope `p≈-6.62836464e-7 s^-1`, with the first two fixed scales
  `1e-6` and `5e-7 m` agreeing to about `5.8e-9` relative;
- the independent MAP09A whole-window tangent cross-check;
- symmetric mass decomposition at the selected scale,
  `J_S≈+5.72690705e-4`, `J_R≈-5.72690705e-4`, and
  `J_nonbottom=0` to reported precision;
- the complete `GW_R05_STORAGE` replay: P1 and P4 both converge from both
  frozen starts in one outer update, with zero P4 contractions.

G12 nevertheless remains failed. In `GW_R2_STORAGE` the frozen one-shot
groundwater head-translation calibration misses the preregistered
`|q_swap(href)-q_gw(href)|<=1e-15 m/s` gate by approximately
`7.56e-15 m/s`. The remaining G12 policy matrix therefore has no G12
qualification.

G12A diagnosed that calibration failure without replaying policy or changing
the failed G12 gate. Seven-point centered local groundwater fits and independent
fixed 20-step q->Href inversions agree within at most about
`1.50e-16 m/s` across all three groundwater regimes, while the local fit
errors themselves are at most about `1.74e-22 m/s`.

The one-shot anchor misses are regime dependent:

```text
GW_R05_STORAGE : qref - q_gw(href) ≈ -5.4e-16 m/s
GW_R2_STORAGE  : qref - q_gw(href) ≈ -7.56e-15 m/s
GW_MIXED       : qref - q_gw(href) ≈ -1.748e-12 m/s
```

The independent direct inversions reproduce essentially the same offsets.
Therefore the G12 failure mechanism is not inadequate local affine fitting.
It is the one-shot head-bias anchoring rule: a head translation inferred from
one constant-flux solve does not force the translated model to satisfy
`q_gw(href)=qref` at the requested coupling tolerance in every groundwater
response regime.

Consequently:

```text
G12 = FALSIFIED UNDER ITS ORIGINAL GROUNDWATER-ANCHOR CONTRACT.
G12A = QUALIFIED DIAGNOSTIC OF THE FAILURE MECHANISM.
DO NOT RELAX OR RETUNE G12.
NO PRODUCTION HCOF/RHS CHANGE.
```

## G12B candidate: active-drainage replay with local groundwater authority

G12B is preregistered as separate evidence. It keeps the MAP09 carrier,
E3_MAP, the two `±1e-6 m` starts, P1/P4 policies, factor-1/2 safeguard and
coupling tolerances unchanged. For each groundwater regime it instead reuses
and independently remeasures the G12A-qualified local response
`q_gw=a(H-href)+q_at_href`.

An independent 50-bisection SWAP-groundwater reference root is required inside
the same fixed `±1e-6 m` interval. G12B can pass only if P4 converges from
both starts in all three regimes and the final head agrees with that
independent root within `5e-10 m`.

A G12B PASS would extend E3/P4 research evidence to the active-drainage MAP09
carrier, but it still would not be production admission. Tangent-acquisition
cost and the explicit production ownership/integration contract remain open.


## G12B disposition: active-drainage process coverage qualified

G12B is separate from the falsified G12 calibration gate. It remeasured the
qualified G12A local groundwater response in each frozen regime and used that
response only as the merit/reference oracle. MAP09 physics, E3_MAP, starts,
P1/P4, the factor-1/2 safeguard and convergence tolerances remained unchanged.

The normalized G12B test is unchanged between the live tested postimage and the
final single-authority runner. The live result is:

```text
groundwater regimes       3
starts per regime          2
P1 converged               6 / 6
P4 converged               6 / 6
P4 raw inadmissible        0
P4 contractions            0
max P4 root-head error     2.615e-11 m
max groundwater fit error  1.736e-22 m/s
```

Each regime has an independent coupled reference root obtained inside the same
frozen `±1e-6 m` bracket. All P4 final heads satisfy the preregistered
`5e-10 m` root agreement gate.

This extends E3/P4 research qualification to the active-drainage MAP09 carrier
across storage-dominated and mixed groundwater response classes. It does not
replace G11: G12B exercises process coverage, while G11 remains the live
evidence that P4 actually recovers an inadmissible Newton proposal by
backtracking.

The remaining pre-production questions are now narrower:

1. the computational cost and API shape of tangent acquisition;
2. whether the research E3 estimator can be reduced to a practical production
   tangent service without changing its semantics;
3. explicit production ownership, transaction and publication integration.

```text
G12 REMAINS FALSIFIED.
G12A DIAGNOSIS = QUALIFIED.
G12B ACTIVE-DRAINAGE E3/P4 COVERAGE = QUALIFIED RESEARCH EVIDENCE.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: TANGENT-ACQUISITION COST AND INTEGRATION.
```


## G15 disposition: FMR same-trial observation building block qualified

G15 moves one narrowly defined part of the G14 research integration shape into
the FMR runtime participant without changing coupling policy. The participant
now retains a read-only observation of the exact trial it already executed:
participant status, q when available, and the execution diagnostics needed to
classify the trial's numerical execution route.

The accessor is deliberately weak. It takes only the participant as
`intent(in)`, copies participant-owned state, has no backend, executor or
materializer collaborator, and performs no procedure call. The normal
`trial_from_origin` path still contains one physical backend run site. Reading
the observation therefore cannot create a second physical SWAP trial, publish a
candidate, stage mass, or commit state.

The first G15 live execution is preserved as a technical test-harness failure.
All eight frozen FGC44 states and 62 streaming heads had already matched the G14
reference, including failed-trial recovery, but the test then executed its
baseline and observed commit paths in one Fortran process. The first legitimate
ledger commit contaminated the second fixture baseline. The repair isolated
those two commit paths in fresh subprocesses and changed no runtime semantics,
numerical thresholds, ledger behavior or coupling rule.

The repaired live qualification, workflow `35720172440`, passed. Its bounded
results are:

```text
FGC44 frozen states                 8
streaming unique heads            62
participant trial calls           62
max q difference vs G14            0 m/s
states containing status 6         5
status-6 -> status-0 recovery       PASS
repeated observation reads          PASS
observation/discard authority       PASS
isolated commit equivalence         PASS
accessor additional backend runs    0
source/ownership contract           PASS
```

The regression also executed 62 independent G14 fused research-oracle runs, one
per head, solely to verify exact status/q/execution-diagnostic equivalence. Those
reference runs are qualification cost, not part of the G15 access path and not
part of the production-facing cost claim.

The G15 lifecycle contract is therefore qualified for this FMR-specific
building block: a new trial attempt resets the previous observation; status-0
leaves a live candidate and readable q; status-6 leaves diagnostic information
with q unavailable and no live candidate; discard leaves historical diagnostic
information but no publication authority; commit remains governed only by the
existing publication/preflight/commit path and resets the observation.

This is intentionally not E3 or P4 production admission. G09D E3 remains a
qualified research estimator, P4 remains the leading research coupling-policy
candidate, and production HCOF/RHS remains unchanged. G15 only removes the
otherwise unnecessary duplicate physical trial from the participant-side data
acquisition boundary.

The next bounded work unit is therefore the tangent-service ownership contract:
it must define how a service consumes these read-only same-trial observations
across a prospectively frozen probe ladder, who owns probe scheduling and cache
lifetime, how failed/diagnostic trials retain zero accepted-state and ledger
authority, and how the service exposes a qualified tangent to coupling
orchestration. That work must be qualified before any real production coupling
policy consumes E3/P4.

```text
G15 FMR SAME-TRIAL OBSERVATION = QUALIFIED PRODUCTION-FACING BUILDING BLOCK.
E3 = QUALIFIED RESEARCH ONLY.
P4 = RESEARCH POLICY CANDIDATE, NOT PRODUCTION AUTHORITY.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: EXPLICIT TANGENT-OBSERVATION / TANGENT-SERVICE OWNERSHIP CONTRACT.
```
## G16 disposition: immutable-origin tangent observation service qualified

G16 moves the next bounded piece of the G14/G15 research integration shape into
the FMR runtime without admitting a coupling policy. The new
`fmr_groundwater_swap_tangent_observation_service_t` owns only probe
scheduling, exact-head cache lifetime and observation transport within one
explicit immutable-origin session. Physical trial execution and diagnostic
candidate ownership remain with the existing FMR participant/backend boundary.

The frozen G13 research E3 caller was replayed unchanged across the same eight
FGC44 states. The live qualification, workflow `35721804825`, produced:

```text
FGC44 frozen states                  8
logical observation requests       103
physical participant trials         62
exact-head cache hits               41
unique cached heads                 62
returned live diagnostic candidates  0
cross-session cache reuse             0
additional backend runs from cache    0
G13 E3 decision equivalence         PASS
immutable-origin authority          PASS
source ownership audit              PASS
```

For every cache miss the service returned exactly the participant-owned G15
observation from that same physical trial. The participant runtime source is
unchanged between the G15-tested commit and the G16-tested commit. G15 had
already compared those participant observations independently with G14 over the
same 62 frozen heads with zero q difference. G16 therefore reuses that frozen
G15/G14 authority chain rather than adding another 62 research-oracle backend
runs merely to repeat the same comparison.

The cache key is the exact prescribed-head real64 bit pattern within one
session. A repeated numeric head in a newly begun session caused a fresh
participant trial, proving that cache authority does not cross session/origin
boundaries. Across every service call the accepted revision/time and
groundwater-interface ledger state remained unchanged. Successful diagnostic
candidates were copied into the observation cache and then discarded through
the participant before returning. Failed participant trials remained diagnostic
only and did not leak a live candidate or accepted-state authority.

The service source contains no direct backend run, backend commit/discard,
groundwater-interface ledger, MODFLOW linear-boundary, HCOF or RHS dependency.
It exposes no commit or publication method. This preserves the preregistered
ownership boundary: the service can request participant trials and participant
cleanup, but cannot acquire state-publication authority.

This is deliberately a building-block qualification only. The frozen G09D/G13
E3 estimator remains research-only, P4 remains a research coupling-policy
candidate, and no production HCOF/RHS behavior changes.

The next natural work unit is end-to-end safeguarded tangent coupling
orchestration. It must consume the qualified G16 service while proving that all
Newton/E3/P4 diagnostic trials remain non-authoritative and that only a final
converged participant candidate may enter the existing preflight/publication
path.

```text
G16 FMR TANGENT OBSERVATION SERVICE = QUALIFIED PRODUCTION-FACING BUILDING BLOCK.
E3 = QUALIFIED RESEARCH ONLY.
P4 = RESEARCH POLICY CANDIDATE, NOT PRODUCTION AUTHORITY.
COUPLING ORCHESTRATION = NOT YET ADMITTED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: END-TO-END SAFEGUARDED TANGENT COUPLING ORCHESTRATION.
```
