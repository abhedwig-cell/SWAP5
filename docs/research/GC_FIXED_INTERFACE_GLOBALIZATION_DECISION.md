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
## G17 disposition: G16-backed safeguarded orchestration qualified as research integration

G17 composes the previously separate G16 tangent-observation service, the
qualified research E3/P4 logic and the existing FMR/groundwater-interface
publication seam on the frozen G11 live-overshoot stress. No runtime coupling
policy was added.

The fully preregistration-bound live run, workflow `35724160855`, reproduced
the G11 path exactly:

```text
first raw Newton dh                  -1.1162302297473836e-5 m
first raw participant status         6
P4 factor-1/2 contractions           2
outer updates                        3
final dh                            -9.999346805233955e-6 m
final residual                      -1.0640987109201395e-20 m/s
```

All SWAP-side current-head, tangent-stencil, raw-Newton and safeguard diagnostic
evaluations were obtained through G16. The complete solve used 67 logical
observation requests, served by 34 physical participant trials and 33 exact-head
cache hits. Ten logical observations returned participant status 6. No ordinary
publication-path participant trial was used during this diagnostic phase.

After every diagnostic observation the participant had no live candidate,
FMR preflight was false, ledger preflight was false and accepted revision/time
plus committed ledger state remained exactly at the immutable origin. This
qualifies the intended non-authority boundary for rejected and diagnostic
Newton/P4 work in this frozen stress.

After convergence, G16 was explicitly closed. The converged head still had no
publication authority. Exactly one ordinary participant trial then reacquired
that final head. Its q matched the cached diagnostic q with zero difference.
Only that reacquired candidate entered FMR preflight and interface-ledger
prepare/preflight.

The nominal publication sequence produced:

```text
before publication                 [revision 0, time 0.00 d, ledger 0]
after SWAP commit                  [revision 1, time 0.01 d, ledger 0]
after ledger commit                [revision 1, time 0.01 d, ledger 1]
committed exchange                 1.3878293167404843e-8 m
```

A fresh-process direct-publication control at the exact final head produced the
same final state and exchange.

That intermediate state after SWAP commit is also important negative evidence:
the current FMR-plus-ledger publication sequence is not crash-atomic. G17 does
not contain a persistent MODFLOW timestep participant at all; its live MODFLOW
calculations remain proposal/merit solves. Therefore G17 qualifies research
orchestration and final-candidate handoff only.

Repository reconciliation after G17 also points to the already-qualified
F-GC38/F-GC39 prepared-solve architecture. There MODFLOW owns one prepared
timestep with fixed accepted `XOLD` and evolving nonlinear `X`; non-converged
coupling iterations explicitly do not rollback `X`. This means the next unit
must first reconcile the head-space P4 safeguard with that continuous
prepared-solve ownership model before final multi-participant publication can
be meaningfully admitted.

```text
G17 G16-BACKED SAFEGUARDED ORCHESTRATION = QUALIFIED RESEARCH EVIDENCE.
DIAGNOSTIC TRIAL NON-AUTHORITY = QUALIFIED IN THE FROZEN G11 STRESS.
FINAL FMR + LEDGER HANDOFF = QUALIFIED ON THE NOMINAL PATH.
E3/P4 = NOT PRODUCTION-ADMITTED.
PERSISTENT MODFLOW TIMESTEP PUBLICATION = NOT PRESENT IN G17.
CRASH-ATOMIC MULTI-PARTICIPANT PUBLICATION = NOT QUALIFIED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: RECONCILE P4 GLOBALIZATION WITH F-GC38/F-GC39 PREPARED-SOLVE SEMANTICS.
```
## G18 disposition: exact head-space P4 is not directly composable with continuous prepared solve

G18 reconciled the frozen G11/G17 head-space P4 safeguard with the current
F-GC38/F-GC39 MODFLOW prepared-solve ownership contract. This was a
compatibility/falsification unit, not a production-policy implementation.

The first execution failed technically before any compatibility verdict because
the harness inferred the factor-1/2 contraction fraction by dividing two small
head differences. It obtained `0.25000000000248657` rather than exactly
`0.25`. The persisted accepted head itself was correct. The failure is
preserved in `GC_FIXED_INTERFACE_G18_FIRST_EXECUTION_RESULT.json`. The repair
replayed the actual P4 arithmetic: two sequential factor-1/2 updates reproduce
the persisted accepted head exactly.

The final hardened qualification, workflow `35725715857`, job
`106738743115`, passed its ownership audit and falsified the direct
composition hypothesis. The frozen transition is:

```text
current head                     -0.7149999311459918 m
raw Newton head                  -0.7150110934482893 m
raw participant status            6
P4 contractions                   2
first accepted head              -0.7150027217215662 m
sequential-halving reconstruction -0.7150027217215662 m
raw-to-contracted separation      8.371726723077622e-6 m
```

The current `Modflow6PreparedSolveSession` exposes exactly the admitted
prepared-solve operations: acquire, open, publish-and-solve, finalize solve,
timestep readiness/finalization, and invalidate. It exposes no admitted
operation to prescribe `X`, restore the prior nonlinear iterate, rollback one
external solve iteration, clone an open prepared solve, or restart that same
open solve from `XOLD`.

The hardened source audit also confirms that `invalidate_without_finalize`
only delegates to `_invalidate`; `_invalidate` only changes the session
flags `invalid` and `solve_open`; and `publish_and_solve_iteration` does
not directly mutate the live `X`, `XOLD`, or accepted-`XOLD` arrays.
F-GC39 independently requires continuous `X` and explicitly forbids
groundwater rollback/discard between nonconverged coupling iterations.

Therefore exact G11/G17 **head-space P4** cannot be inserted unchanged into the
current F-GC38/F-GC39 continuous prepared-solve lifecycle. Achieving the
contracted head after observing the bad raw iterate would require an additional
state-control or reconstruction capability that is not admitted today.

This falsifies only the direct composition hypothesis. It does not falsify the
G11/G17 P4 research evidence and does not weaken the qualified F-GC38/F-GC39
prepared-solve architecture. Directly writing through the technically writable
NumPy `X` pointer is explicitly not an admissible workaround because it would
bypass the qualified ownership contract.

The next research bridge is response-space globalization. With an affine
groundwater response and fixed SWAP tangent, damping the affine response
intercept may map algebraically to the same contracted head without directly
setting or rolling back MODFLOW `X`. That is a distinct policy and must be
preregistered and qualified separately before any claim of equivalence or
production use.

```text
G18 DIRECT EXACT-P4 / F-GC38-F-GC39 COMPOSITION = FALSIFIED.
P4 HEAD-SPACE SAFEGUARD = REMAINS QUALIFIED RESEARCH EVIDENCE.
F-GC38/F-GC39 PREPARED-SOLVE OWNERSHIP = UNCHANGED.
DIRECT X POINTER MUTATION = NOT ADMITTED.
E3/P4 PRODUCTION POLICY = NOT ADMITTED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: RESPONSE-SPACE DAMPING BRIDGE.
```

## G19 disposition: affine response-space damping reproduces the frozen P4 contraction geometry

G19 followed the G18 composition falsification with a distinct, preregistered
bridge. It did not attempt to prescribe or restore MODFLOW `X`. Instead it
kept the frozen G11 physical SWAP tangent fixed and damped only the affine
response anchor.

For current head `h0`, affine groundwater response `G(h)=a h+b`, current
real-SWAP flux `qS0`, residual `r0=qS0-G(h0)` and physical tangent `p`,
G19 used

```text
q_ref(lambda) = G(h0) + lambda * r0
L_lambda(h)   = q_ref(lambda) + p * (h-h0)
```

For affine `G`, solving `L_lambda(h)=G(h)` gives exactly

```text
h_lambda = h0 + lambda * (h_raw-h0).
```

The final deduplicated live qualification, workflow `35726466434`, job
`106741215877`, passed. The independently remeasured groundwater fit had a
maximum error of `3.705769144237564e-21 m/s`. The three frozen response
levels produced:

```text
lambda = 1
  live head             -0.7150110934482893 m
  error vs raw P4 head   0
  SWAP status             6
  accepted                no

lambda = 1/2
  live head             -0.7150055122971404 m
  geometry error          2.220446049250313e-16 m
  SWAP status             6
  accepted                no

lambda = 1/4
  live head             -0.7150027217215658 m
  error vs first accepted P4 head
                          4.440892098500626e-16 m
  SWAP status             0
  accepted                yes
```

The unchanged G11 merit/admissibility rule therefore sees exactly the same
first safeguard topology under the fresh-origin affine response bridge:
the full response and first half response remain inadmissible, while the
quarter response reaches the first accepted P4 head.

All four SWAP observations, including the current head, ran through G16 and
remained diagnostic-only. Accepted FMR revision/time and committed interface
ledger state did not change, and no live candidate escaped the observations.

This result is deliberately narrower than a prepared-solve-native
globalization policy. Every lambda response in G19 was solved from the same
accepted groundwater origin in a fresh MODFLOW prepared solve. G19 therefore
qualifies the algebraic/live **bridge**, not yet its behavior while `X`
continues through one open F-GC38 prepared solve.

```text
G19 AFFINE RESPONSE-SPACE BRIDGE = QUALIFIED IN FROZEN G11 FRESH-ORIGIN SOLVES.
G18 DIRECT HEAD-SPACE COMPOSITION FALSIFICATION = UNCHANGED.
CONTINUOUS F-GC38 RESPONSE-SPACE GLOBALIZATION = NOT YET QUALIFIED.
E3/P4 PRODUCTION POLICY = NOT ADMITTED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: ONE CONTINUOUS PREPARED-SOLVE LAMBDA SEQUENCE.
```

## G20 disposition: response-space damping traverses one continuous prepared solve

G20 moved the G19 response-space bridge into the actual F-GC38 ownership
model. The three frozen response levels were no longer solved from separate
groundwater origins. They were published successively inside one open MODFLOW
prepared solve with fixed accepted `XOLD` and continuously evolving `X`.

The final fail-closed qualification, workflow `35727618026`, job
`106745027381`, passed:

```text
prepare_time_step calls             1
prepare_solve calls                 1
MODFLOW solve calls                 6
finalize_solve calls                1
finalize_time_step calls            0
XOLD drift                           none
direct X/XOLD control                none

lambda 1
  solve calls in phase               2
  continuous head                  -0.7150110934482893 m
  difference from G19 fresh solve    0
  SWAP status                        6

lambda 1/2
  solve calls in phase               2
  continuous head                  -0.7150055122971403 m
  difference from G19 fresh solve    1.1102230246251565e-16 m
  SWAP status                        6

lambda 1/4
  solve calls in phase               2
  continuous head                  -0.7150027217215658 m
  difference from G19 fresh solve    0
  SWAP status                        0
```

The maximum continuous-path versus fresh-origin head difference is
`1.1102230246251565e-16 m`, far inside the preregistered F-GC38 nonlinear
path-equivalence guard of `1.4901161193847656e-8 m`. The guard was inherited
prospectively; it was not tightened after seeing the result.

The test also binds explicitly to the G18 direct-composition falsification.
No head prescription, previous-iterate restore, rollback, solve reopen or direct
write through the X/XOLD pointers occurs. The prepared solve remains open and
valid through all three response phases. Thus the G18 gap is bridged in this
bounded affine case by changing the **published response**, not by rewinding
groundwater state.

Each settled groundwater head was checked against real SWAP through G16.
Those diagnostic observations preserve the exact frozen status topology
`[6, 6, 0]`, leave no live SWAP candidate and do not change accepted FMR
revision/time or the committed interface ledger.

G20 still does not establish a complete response-space coupling algorithm. It
qualifies only the first safeguarded G11 update transported through one
continuous prepared solve. `finalize_solve` is used once for solve lifecycle
closure, but `finalize_time_step` is deliberately not called, so no accepted
groundwater timestep is published.

```text
G20 CONTINUOUS F-GC38 RESPONSE-SPACE BRIDGE = QUALIFIED BOUNDED RESEARCH.
G18 DIRECT HEAD-SPACE COMPOSITION = REMAINS FALSIFIED.
G19 FRESH-ORIGIN AFFINE BRIDGE = REMAINS QUALIFIED.
FULL RESPONSE-SPACE OUTER COUPLING = NOT YET QUALIFIED.
MODFLOW TIMESTEP PUBLICATION = NOT PERFORMED.
E3 / RESPONSE-DAMPING PRODUCTION POLICY = NOT ADMITTED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: FULL MULTI-OUTER-UPDATE CONTINUOUS PREPARED-SOLVE COUPLING.
```
## G21A disposition: G21 outer-2 divergence is prepared-solve-path dominated

G21A decomposed the first failing G21 outer-2 head into response-parameter
sensitivity and continuous prepared-solve path dependence without changing any
G21 gate or coupling policy.

The first G21A workflow attempt did not execute G21A: the general research
runner stopped on the already-preserved G21 falsification. That infrastructure
failure is retained separately. The repaired authority run, workflow
`35730386461`, first reproduced the exact persisted G21 outer-2 assertion and
then executed the preregistered G21A decomposition successfully.

At the two outer-1 anchors, separated by only
`4.440892098500626e-16 m`, E3 selected the same
`BACKWARD_CENTER_CLASS` stencil and `6.25e-8 m` scale. The slope changed
from `-1.5956003185379992e-6 s^-1` to
`-1.5956002568589343e-6 s^-1`, a difference of
`6.167906494690411e-14 s^-1`.

Fresh-origin live MODFLOW solves show that this response change is not the
material G21 error. The G21-native response differs from the frozen G17 outer-2
head by only `-1.978417429882029e-13 m`. Cross-evaluation attributes almost
all of even that small difference to the E3 tangent change; retaining the G17
tangent at the G21 anchor changes the fresh root by less than `1e-15 m`.

The dominant component appears only when the exact same G21-native outer-2
response is applied after the continuous outer-1 lambda history in one prepared
solve:

```text
observed G21 outer-2 divergence       7.215394948190124e-11 m
fresh response-parameter effect      -1.978417429882029e-13 m
continuous-path effect                7.235179122488944e-11 m
reconstructed divergence              7.215394948190124e-11 m
reconstruction error                  0.0 m
classification                        PREPARED_SOLVE_PATH_DOMINATED
```

The continuous outer-2 response required six MODFLOW solve calls, compared with
two for the corresponding fresh solve. All SWAP observations remained
diagnostic through G16: 61 logical observations, 31 physical participant
trials, 30 cache hits, zero ordinary publication-path trials and no accepted
state or ledger mutation.

This result preserves both sides of the earlier evidence. G19 remains a valid
affine response-space bridge, and G20 remains a valid bounded first-update
continuous prepared-solve bridge. G21 remains falsified at its deliberately
strict `1e-12 m` G17 trajectory-equivalence gate. The measured
`7.24e-11 m` path effect is still well inside the much looser inherited
F-GC38 path-equivalence envelope, so G21A does not falsify F-GC38/F-GC39.

The next unit is therefore not another tangent or damping redesign. It is a
prepared-solve convergence/path diagnostic: hold the exact outer-2 response
fixed and determine what the MODFLOW convergence report means at this strict
trajectory scale, including whether additional same-response solve calls move
the state toward the fresh-origin solution.

```text
G21A DIVERGENCE DECOMPOSITION = QUALIFIED DIAGNOSTIC.
CAUSE = PREPARED-SOLVE PATH DOMINATED.
RESPONSE-PARAMETER EFFECT = SUBTHRESHOLD.
G21 = REMAINS FALSIFIED.
G19/G20 = REMAIN QUALIFIED BOUNDED RESEARCH.
F-GC38/F-GC39 = UNCHANGED.
NO PRODUCTION HCOF/RHS OR COUPLING-POLICY ADMISSION.
NEXT: G21B PREPARED-SOLVE CONVERGENCE/PATH DIAGNOSIS.
```
## G21B disposition: outer-2 path effect persists after convergence

G21B tested whether the G21A outer-2 divergence was merely a first-convergence
report artifact. It held the exact same outer-2 HCOF/RHS response fixed for 12
successive MODFLOW solve calls in two independent prepared solves: a fresh arm
and a history arm that first replayed the frozen outer-1 lambda sequence.

The authority run, workflow `35731373754`, job `106757502990`, passed its
diagnostic gates. The fresh arm reached the frozen fresh response head immediately
and reported MODFLOW convergence on call 2. Its middle-cell head then remained
unchanged through call 12.

The history arm approached a different fixed head:

```text
first outer-2 convergence call                    6
path offset at first convergence       7.235179122488944e-11 m
path offset after call 12              7.235112509107466e-11 m
offset reduction after convergence     6.661338147750939e-16 m
per-call post-convergence head change  1.1102230246251565e-16 m
```

The identical-response continuation therefore does not drive the history arm
toward the fresh arm at the strict G21 `1e-12 m` trajectory scale. XOLD remains
bitwise fixed, the outer-2 HCOF/RHS values are bitwise identical between arms,
and neither arm finalizes the MODFLOW timestep.

This rejects the bounded explanation that G21 failed only because MODFLOW
reported convergence too early. Instead, the difference behaves as persistent
prepared-solve path memory for this fixture. G21B does not identify which
internal state carries that memory and does not alter the meaning of MODFLOW
convergence.

```text
G21B FIXED-RESPONSE CONTINUATION = QUALIFIED DIAGNOSTIC.
FIRST-CONVERGENCE-TOLERANCE EXPLANATION = REJECTED IN THIS FIXTURE.
PERSISTENT PREPARED-SOLVE PATH MEMORY = SUPPORTED AT STRICT G21 SCALE.
G21 = REMAINS FALSIFIED.
G19/G20 = REMAIN QUALIFIED BOUNDED RESEARCH.
F-GC38/F-GC39 = UNCHANGED.
NO PRODUCTION HCOF/RHS OR COUPLING-POLICY ADMISSION.
NEXT: G21C READ-ONLY MODFLOW/XMI STATE FORENSICS.
```
## G21C disposition: visible solver-history state located, causality still open

G21C followed the G21B persistent-path result with read-only MODFLOW/XMI
forensics. It compared FRESH and HISTORY at matched outer-2 stages while keeping
the accepted origin and the published response fixed. No XMI/BMI state pointer
was mutated.

The first execution was technically invalid because the two tail-entry snapshots
were taken before the same outer-2 API response had been staged in both arms.
That run is preserved separately. The repaired authority run, workflow
`35732842184`, job `106762486571`, passed all forensic gates and reproduced
the exact G21B call-12 path offset:

```text
HISTORY minus FRESH X at call 12     7.235112509107466e-11 m
XOLD difference                       0
outer-2 HCOF difference               0
outer-2 RHS difference                0
NONMETH                               3 in both arms
```

MODFLOW6 6.8.0's MODERATE IMS configuration uses delta-bar-delta
under-relaxation. The source-backed history arrays are visibly different at
call 12:

```text
                         FRESH                  HISTORY
WSAVE, middle            1.0                    0.9004
HCHOLD, middle           2.322023516376781e-5  -7.264273627072271e-10
DEOLD, middle            2.322023516376781e-5  -7.264273627072271e-10
DXOLD, middle            2.322023516376781e-5  -7.264273627072271e-10
```

NPF `SAT` also differs at the middle cell by about
`3.617584010129349e-11`, consistent with the different current head. NPF
conductance/static fields and all probed STO fields remain equal. Solver
configuration is identical. Bookkeeping counters differ as expected because
the HISTORY arm has more solve calls and are therefore not treated as physical
state evidence.

Under the preregistered classification rules the formal result is
`MIXED_OR_UNRESOLVED`: both explicit solver-history carriers and an NPF
dynamic quantity differ. The stronger source interpretation is bounded:
`WSAVE/HCHOLD/DEOLD` are genuine persistent delta-bar-delta history carriers,
so G21C has located a concrete non-XOLD memory candidate. It has not proven
that this state causes the head offset. No reset, state setter or new
convergence rule follows from this result.

```text
G21C READ-ONLY STATE FORENSICS = QUALIFIED DIAGNOSTIC.
FORMAL CLASSIFICATION = MIXED_OR_UNRESOLVED.
DELTA-BAR-DELTA HISTORY STATE = VISIBLY PATH-DEPENDENT.
CAUSAL ATTRIBUTION = NOT YET QUALIFIED.
G21 = REMAINS FALSIFIED.
F-GC38/F-GC39 = UNCHANGED.
NO PRODUCTION HCOF/RHS OR COUPLING-POLICY ADMISSION.
NEXT: G21D PAIRED DBD CAUSAL-ISOLATION DIAGNOSTIC.
```
## G21D disposition: delta-bar-delta causally supports the strict prepared-solve path memory

G21D converted the G21C state-forensics candidate into a matched causal-isolation
experiment. Four independent live MODFLOW6 prepared solves were run on the same
real-FGC44 carrier: STANDARD-FRESH, STANDARD-HISTORY, NOUR-FRESH and
NOUR-HISTORY. The only controlled intervention was nonlinear under-relaxation at
solver construction. STANDARD retained MODERATE delta-bar-delta
(`NONMETH=3`); NOUR used `UNDER_RELAXATION NONE` (`NONMETH=0`).

The first G21D execution stopped technically before any intervention arm because
the harness referenced a nonexistent `tail_calls` member in the G21B
`frozen_case`. That failure is preserved. The repair bound the fixed 12-call
tail to the closed G21B result authority and changed no physical, numerical or
causal gate.

The repaired authority run, workflow `35734305678`, job `106767481903`,
passed the strengthened root-comparability gate. The standard pair exactly
reproduced G21B:

```text
STANDARD FRESH call-12 head          -0.7150100297648362 m
STANDARD HISTORY call-12 head        -0.7150100296924851 m
HISTORY - FRESH                       7.235112509107466e-11 m
NONMETH                               3 / 3
```

With nonlinear under-relaxation disabled from initialization:

```text
NOUR FRESH call-12 head              -0.7150100297648362 m
NOUR HISTORY call-12 head            -0.7150100297648363 m
HISTORY - FRESH                      -1.1102230246251565e-16 m
NONMETH                               0 / 0
absolute offset reduction             99.99984655068967 %
```

The intervention did not move the matched response roots at the strict G21
scale. The NOUR fresh outer-2 root error is zero and all three NOUR outer-1
lambda roots reproduce their frozen STANDARD references exactly. XOLD remains
fixed in every arm, the outer-2 HCOF/RHS response is identical across
configurations, no MODFLOW state is mutated through XMI pointers and
`finalize_time_step` is never called.

Under the preregistered rules this is
`DELTA_BAR_DELTA_CAUSAL_SUPPORT`: delta-bar-delta nonlinear under-relaxation
history is a causal carrier of the strict prepared-solve path memory in this
frozen real-FGC44 case. This does not mean that delta-bar-delta is wrong in
MODFLOW or that production SWAP-MODFLOW coupling should disable it. It shows a
specific composition interaction when the external coupler replaces the affine
response between nonlinear solve calls.

G21 remains falsified under the standard configuration. G21D explains the
dominant mechanism but does not retroactively alter that result, F-GC38/F-GC39,
or production solver configuration.

```text
G21D MATCHED DBD CAUSAL ISOLATION = QUALIFIED DIAGNOSTIC.
STANDARD HISTORY OFFSET = 7.235112509107466e-11 m.
NOUR HISTORY OFFSET = -1.1102230246251565e-16 m.
ROOT COMPARABILITY = PASS AT 1E-12 m.
DELTA-BAR-DELTA CAUSAL SUPPORT = YES, FROZEN CASE ONLY.
PRODUCTION IMS CONFIGURATION = UNCHANGED.
E3 / RESPONSE-SPACE GLOBALIZATION = NOT PRODUCTION-ADMITTED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: FULL DYNAMIC SOLVER-CONFIGURATION / COUPLING-POLICY COMPARISON.
```
## G21D disposition: delta-bar-delta is causally implicated in the frozen path memory

G21D converted the G21C state localization into a matched causal-isolation
experiment. Four independent live MODFLOW6 prepared solves were run with the
same physical model, accepted XOLD, response sequence, solver tolerances and
12-call outer-2 tail. The only intervention was nonlinear under-relaxation
chosen before solver initialization:

```text
STANDARD: MODERATE default      NONMETH = 3  delta-bar-delta
NOUR:     UNDER_RELAXATION NONE NONMETH = 0
```

The authority run, workflow `35734305678`, job `106767481903`, first
reproduced the closed G21B positive control exactly:

```text
STANDARD FRESH call-12 head       -0.7150100297648362 m
STANDARD HISTORY call-12 head     -0.7150100296924851 m
HISTORY minus FRESH                7.235112509107466e-11 m
```

The no-under-relaxation treatment preserved all matched response roots at the
strict G21 scale. The FRESH outer-2 root error was zero and all three HISTORY
outer-1 lambda roots reproduced their frozen references exactly. Under those
matched conditions:

```text
NOUR FRESH call-12 head           -0.7150100297648362 m
NOUR HISTORY call-12 head         -0.7150100297648363 m
HISTORY minus FRESH               -1.1102230246251565e-16 m
absolute path-offset reduction     99.99984655068967 %
```

Thus the persistent path offset collapses from about `7.24e-11 m` to
floating-point scale when delta-bar-delta under-relaxation history is removed,
without moving the frozen response roots. Under the preregistered matched
design this qualifies **DELTA_BAR_DELTA_CAUSAL_SUPPORT** for the strict path
memory in this one real-FGC44 fixture.

The interpretation is deliberately narrow. Delta-bar-delta is not declared
wrong, and the qualified F-GC38/F-GC39 solver configuration is not changed.
The experiment demonstrates an interaction between persistent nonlinear-solver
history and changing externally assembled affine responses. Whether a no-UR
coupling route is robust, efficient and scientifically acceptable across the
full dynamic E3/P4 path remains a separate question.

```text
G21D DBD CAUSAL ISOLATION = QUALIFIED DIAGNOSTIC.
DBD HISTORY = CAUSALLY SUPPORTED AS CARRIER OF THE STRICT PATH EFFECT.
NOUR = RESEARCH INTERVENTION ONLY.
G21 STANDARD-CONFIGURATION EQUIVALENCE = REMAINS FALSIFIED.
F-GC38/F-GC39 = UNCHANGED.
NO PRODUCTION IMS, HCOF/RHS OR COUPLING-POLICY CHANGE.
NEXT: FULL DYNAMIC STANDARD-DBD VERSUS NOUR COUPLING COMPARISON.
```
## G21E disposition: both solver configurations converge physically, neither is selected

G21E executed the complete dynamic G16/E3 response-space coupling loop as a
matched solver-configuration comparison. STANDARD used the admitted MODERATE
delta-bar-delta setting (`NONMETH=3`); NOUR disabled nonlinear
under-relaxation from initialization (`NONMETH=0`). Production configuration
and coupling policy were not changed.

The final authority run, workflow `35735804287`, job `106772601959`,
first reproduced the archived G21 STANDARD control exactly at the outer-2
trajectory scale. It then completed both arms:

```text
                              STANDARD DBD              NOUR
physical classification       CONVERGED                 CONVERGED
final head error vs G17       -1.2789381e-10 m          -1.6653345e-15 m
final coupling residual        2.9505124e-16 m/s        -6.9063539e-21 m/s
MODFLOW solve calls            17                        24
accepted outer updates          3                         5
response contractions           2                         7
physical SWAP diagnostic runs  34                        63
```

Both endpoints pass the preregistered `5e-10 m` reference-head comparison and
the unchanged `1e-15 m/s` external coupling residual gate. Both keep XOLD
fixed, use one prepared solve, retain diagnostic-only SWAP authority and stop
before MODFLOW timestep publication.

The strict trajectory story is different. STANDARD reproduces the known G21
outer-2 offset of `7.215394948190124e-11 m` and remains outside the
`1e-12 m` trajectory-equivalence gate, yet still converges physically.
NOUR removes the DBD path-memory mechanism but does not recover the G17 accepted
trajectory. Its outer-2 lambda=1 response settles only about `2e-13 m` from
the G17 outer-2 reference head, but that tiny shift changes the real-SWAP
participant result from status 0 to status 6. The safeguard therefore contracts
twice at outer 2, three times at outer 3, and reaches the same endpoint through
a longer five-update path.

This separates three concepts that must not be conflated: prepared-solve path
memory, physical coupled endpoint convergence, and SWAP participant
admissibility topology. Removing the first does not automatically improve the
other two, and G21E provides no basis for selecting NOUR as a production solver
configuration.

```text
G21E MATCHED STANDARD-vs-NOUR COMPARISON = QUALIFIED BOUNDED RESEARCH.
STANDARD DBD = PHYSICALLY CONVERGED; STRICT G21 PATH EQUIVALENCE STILL FALSIFIED.
NOUR = PHYSICALLY CONVERGED; G17 TRAJECTORY NOT RECOVERED; HIGHER COST IN THIS CASE.
PRODUCTION IMS CONFIGURATION = UNCHANGED.
E3 / RESPONSE-SPACE GLOBALIZATION = RESEARCH ONLY.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: RESOLVE THE OUTER-2 STATUS-0 / STATUS-6 ADMISSIBILITY BOUNDARY.
```
## G21E disposition: both solver configurations close physically, but by different paths and costs

G21E widened the G21D mechanism result into a complete dynamic coupling
comparison. Two independent real-FGC44 arms used the same G16/E3
response-space safeguard logic, accepted groundwater origin, forcing, physical
tolerances and transaction boundaries. STANDARD retained MODERATE
delta-bar-delta (`NONMETH=3`); NOUR disabled nonlinear under-relaxation at
solver initialization (`NONMETH=0`).

The first execution was a technical preregistration-status mismatch and ran
neither comparison arm. It is preserved separately. The repaired authority run,
workflow `35735804287`, job `106772601959`, reproduced the archived G21
STANDARD control exactly and completed both configurations.

STANDARD converged in three accepted outer updates:

```text
MODFLOW solve calls                  17
response contractions                2
physical SWAP diagnostic trials     34
final head              -0.7150099306206908 m
G17 endpoint error       -1.2789380665623185e-10 m
final coupling residual   2.950512426424542e-16 m/s
status topology           [6,6,0,0,0]
```

Its outer-2 G17 trajectory error is again
`7.215394948190124e-11 m`, so the strict G21 trajectory-equivalence
falsification remains intact. Nevertheless, the final external coupling
residual is below `1e-15 m/s` and the endpoint lies inside the independently
preregistered `5e-10 m` reference guard.

NOUR also converged, but along a substantially different safeguard path:

```text
MODFLOW solve calls                  24
response contractions                7
physical SWAP diagnostic trials     63
accepted outer updates               5
final head              -0.7150099304927987 m
G17 endpoint error       -1.6653345369377348e-15 m
final coupling residual  -6.906353885229705e-21 m/s
status topology           [6,6,0,6,6,0,6,6,6,0,0,0]
```

Thus removing delta-bar-delta removes the strict prepared-solve path memory
identified by G21D, but does not recreate the G17 accepted trajectory. At the
second outer update, the NOUR lambda-1 head lies essentially on the fresh/G17
response root yet is participant status 6, so the safeguard contracts to a
different status-0 branch and subsequently requires additional outer updates.

This distinction matters. Both configurations are physically reference-qualified
in this one frozen case, while STANDARD is cheaper in MODFLOW and SWAP
diagnostic work. NOUR gives an endpoint much closer to the independent G17
reference, but that alone is not a basis for solver-configuration selection.
The next uncertainty is local participant admissibility around the outer-2
fresh response root: a head displacement of only about `7e-11 m` separates
the NOUR status-6 raw response from the STANDARD status-0 accepted response.

```text
G21E MATCHED DYNAMIC COMPARISON = QUALIFIED RESEARCH.
STANDARD DBD PHYSICAL ENDPOINT = QUALIFIED IN FROZEN CASE.
NOUR PHYSICAL ENDPOINT = QUALIFIED IN FROZEN CASE.
STANDARD STRICT G17 TRAJECTORY = REMAINS FALSIFIED.
NOUR STRICT G17 TRAJECTORY = NOT RECOVERED.
SOLVER-CONFIGURATION SELECTION = NOT MADE.
PRODUCTION IMS CONFIGURATION = UNCHANGED.
E3 / RESPONSE-SPACE GLOBALIZATION = NOT PRODUCTION-ADMITTED.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: LOCAL OUTER-2 PARTICIPANT ADMISSIBILITY-BOUNDARY DIAGNOSTIC.
```
## G21F disposition: outer-2 participant admissibility is nonmonotone at sub-picometre head scale

G21F resolved the local real-FGC44 participant status topology around the
G21E NOUR/G17 outer-2 split without changing any participant, solver or
coupling-policy setting. The first execution failed technically before the
scan because a redundant preregistered head-difference field differed by one
binary64 ulp from the subtraction of the two frozen head anchors. The primary
anchor heads were unchanged; the repaired harness derives and reports their
binary64 separation directly.

The authority run, workflow `35737526010`, job `106778498746`, reproduced
all three frozen anchors:

```text
NOUR outer-2 lambda=1   h = -0.7150100297648363 m   participant status 6
G17 outer-2 accepted    h = -0.7150100297646383 m   participant status 0
STANDARD outer-2        h = -0.7150100296924844 m   participant status 0
```

The NOUR-to-G17 interval is only `1.979527652906654e-13 m`, corresponding to
1783 binary64 representable head steps in this range. A preregistered 33-head
scan across that interval produced:

```text
[6,6,0,0,0,0,0,0,6,6,6,6,6,6,6,0,0,0,0,0,0,6,6,6,6,6,6,6,6,0,0,0,0]
```

This contains five status transitions and two status-0 to status-6 reversals.
The topology is therefore not a single monotone admissibility threshold.
According to the preregistration, binary64 bisection to one adjacent
status-6/status-0 pair is not meaningful and was not performed.

The anchor diagnostics expose a discrete execution difference but do not yet
explain the alternating islands. The NOUR status-6 trial terminates with
`result_status=2`, one solver rejection, eight temporal rejections, nine
attempts, one transaction call and zero accepted substeps. The G17 and
STANDARD status-0 trials complete 20 accepted substeps over 100 attempts, with
80 temporal rejections but zero solver rejection. Mass rejection and
temporal-unavailable rejection remain zero at these anchors.

All G21F observations stayed behind the qualified G16 diagnostic boundary.
No live candidate, accepted SWAP revision/time, committed ledger or publication
preflight authority was acquired.

The consequence is negative but useful: the G21E solver-configuration split
must not be interpreted through a smooth head-distance robustness metric. A
head snap, epsilon tolerance, or acceptance smoothing around the G17 root is
not supported by the evidence. The next unit must diagnose the internal
trial/retry/solver branch that generates the alternating status islands.

```text
G21F LOCAL ADMISSIBILITY TOPOLOGY = NONMONOTONE_OR_UNRESOLVED.
33-HEAD INTERVAL = 1.979527652906654e-13 m / 1783 ULP.
STATUS TRANSITIONS = 5.
STATUS REVERSALS = 2.
SINGLE HEAD THRESHOLD = REJECTED BY EVIDENCE.
STATUS 6 SEMANTICS = UNCHANGED.
SOLVER-CONFIGURATION SELECTION = NOT MADE.
NO PRODUCTION IMS, E3/P4, HCOF/RHS OR PARTICIPANT CHANGE.
NEXT: SOURCE-LEVEL TRIAL/RETRY/SOLVER ISLAND DIAGNOSIS.
```
## G21F disposition: local participant admissibility is nonmonotone

G21F resolved the local real-SWAP participant topology around the G21E
STANDARD/NOUR outer-2 split without changing participant acceptance semantics.
The repaired authority run, workflow `35737526010`, job `106778498746`,
first reproduced all three frozen anchors:

```text
NOUR head      -0.7150100297648363 m   participant status 6
G17 head       -0.7150100297646383 m   participant status 0
STANDARD head  -0.7150100296924844 m   participant status 0
```

The NOUR-to-G17 interval is only `1.979527652906654e-13 m`, but still spans
1783 binary64 representable head values. A preregistered 33-head ordered scan
across that interval returned:

```text
6 6 0 0 0 0 0 0 6 6 6 6 6 6 6 0 0 0 0 0 0 6 6 6 6 6 6 6 6 0 0 0 0
```

This contains five status transitions and two status-0 to status-6 reversals.
The topology is therefore not a single monotone admissibility threshold. Under
the preregistered rules, binary64 endpoint bisection and a one-threshold claim
are forbidden.

The anchor diagnostics show a discrete execution distinction but do not yet
explain the islands. The NOUR status-6 anchor fails after nine attempts with
eight temporal rejections, one solver rejection and one internal retry, and no
accepted substep. The G17 and STANDARD status-0 anchors both complete twenty
accepted substeps after one hundred attempts and eighty temporal rejections,
with zero solver rejection. Mass and temporal-unavailable rejection are zero at
all three anchors.

This makes the G21E interpretation sharper. Tiny head changes can move the
participant between alternating execution/admissibility islands, so strict
trajectory fidelity is not a smooth robustness metric and removing MODFLOW
solver path memory need not reduce coupling cost.

```text
G21F LOCAL ADMISSIBILITY TOPOLOGY = QUALIFIED DIAGNOSTIC.
SINGLE HEAD THRESHOLD = REJECTED BY EVIDENCE.
33-HEAD SCAN = 5 TRANSITIONS, 2 REVERSALS OVER 1.98E-13 m.
HEAD SNAPPING / STATUS SMOOTHING = NOT JUSTIFIED.
PARTICIPANT STATUS-6 SEMANTICS = UNCHANGED.
STANDARD-vs-NOUR PRODUCTION SELECTION = NOT MADE.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: REPEAT ISLAND TOPOLOGY AND LOCALIZE THE EXACT EXECUTION/REJECTION BRANCH.
```
## G21G disposition: deterministic retry-solver bifurcation across the G21F status islands

G21G replayed the exact 33 frozen binary64 heads from G21F in three independent
fresh G16 sessions and paired every participant result with a read-only snapshot
of the final corrector-backend physical observation. No runtime execution,
participant acceptance, solver configuration or production policy was changed.

The live qualification, workflow `35739259365`, job `106784404665`, reproduced
the same six contiguous status islands in all three sessions:

```text
indices  0..1   status 6
indices  2..7   status 0
indices  8..14  status 6
indices 15..20  status 0
indices 21..28  status 6
indices 29..32  status 0
```

Each session executed exactly 33 physical participant trials for 33 unique heads
and zero cache hits. The complete participant-status vectors and island
boundaries were identical to G21F, and the read-only backend observation
snapshots were also exactly repeatable in this frozen experiment.

Every status-6 head has one and the same terminal transaction signature:

```text
attempts                         9
retries                          8
temporal rejections              8
solver rejections                1
mass rejections                  0
temporal-unavailable rejections  0
accepted substeps                0
final physical solver status     2
final nonlinear iterations      16
final internal retries           1
temporal certificate available  false
```

The corresponding status-0 heads form one successful execution class in this
scan: 20 accepted substeps, 100 attempts, 80 temporal rejections, zero solver
rejections, final solver status 1 and an available temporal certificate.

The interpretation is therefore narrower and stronger than the earlier
G21F description. The nonmonotone local status topology is not explained by
fresh-session nondeterminism. It is a deterministic bifurcation in the existing
transaction/retry plus physical-solver execution path under binary64-adjacent
head perturbations. Status 6 remains a real inadmissible diagnostic trial; no
smoothing, retry-limit change or tolerance relaxation is justified by G21G.

```text
G21G ISLAND REPEATABILITY = QUALIFIED.
G21G MECHANISM = DETERMINISTIC RETRY-SOLVER BIFURCATION.
SESSION NONDETERMINISM = REJECTED AS EXPLANATION IN THE FROZEN SCAN.
STATUS SMOOTHING / RETRY-TOLERANCE CHANGE = NOT JUSTIFIED.
STANDARD/NOUR PRODUCTION SELECTION = NOT MADE.
RESPONSE-SPACE GLOBALIZATION = RESEARCH ONLY.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: ADJACENT-HEAD PHYSICAL-SOLVER FORENSICS.
```
## G21H disposition: final retry isolates the physical-solver status bifurcation

G21H decomposed the frozen G21G transaction signature into its nine retry
durations without changing runtime, solver or participant policy. Each probe
copied the saved corrector numerical configuration, set `max_retries=0` only in
that copy, captured a fresh immutable-origin checkpoint and discarded any raw
backend candidate before returning.

The authority run, workflow `35740488540`, job `106788659599`, reproduced
the exact mechanism at both representative opposite-direction island
boundaries:

```text
retry levels 0..7:
    physical solver status       CONVERGED
    temporal rejection           1 per isolated attempt
    temporal certificate         available

retry level 8, status-6 side:
    duration                     3.90625e-5 day
    physical solver status       NONCONVERGED
    solver rejection             1
    temporal rejection           0
    nonlinear iterations         16
    Jacobian builds              16
    linear solves                16
    internal retries             1

retry level 8, adjacent status-0 side:
    physical solver status       CONVERGED
    candidate/result             accepted for the isolated duration
```

The same pattern holds for both the frozen `6 -> 0` and `0 -> 6` boundaries.
Thus the full participant status split does not require hidden transaction
history to explain the terminal classification. The first eight retry levels
are physically converged but fail the temporal certificate; after the retry
ladder reaches its smallest duration, the immediately adjacent binary64 heads
split in the physical nonlinear solver itself.

The two failing final-retry heads both exhaust 16 nonlinear iterations, but
their backtracking work differs materially: 104 attempts at the first boundary
and 39 at the second. That makes the next unresolved mechanism local to the
physical nonlinear-solver trajectory rather than the transaction retry ladder.

The research probe was also checked functionally for configuration leakage.
After all isolated attempts, a normal G16 session at the same four frozen heads
reproduced exactly `6, 0, 0, 6`, with four physical trials, zero cache hits and
unchanged accepted revision/time/ledger authority.

```text
G21H RETRY-LEVEL MECHANISM = QUALIFIED.
LEVELS 0..7 = SOLVER-CONVERGED, TEMPORALLY REJECTED.
LEVEL 8 STATUS-6 SIDE = PHYSICAL-SOLVER NONCONVERGENCE.
LEVEL 8 ADJACENT STATUS-0 SIDE = PHYSICAL-SOLVER CONVERGENCE.
TRANSACTION-HISTORY DEPENDENCE = NOT REQUIRED FOR THIS TERMINAL SPLIT.
STATUS SMOOTHING / RETRY POLICY / SOLVER TOLERANCE CHANGE = NOT ADMITTED.
RESPONSE-SPACE GLOBALIZATION = RESEARCH ONLY.
NO PRODUCTION HCOF/RHS CHANGE.
NEXT: FINAL-RETRY NEWTON / BACKTRACKING TRAJECTORY FORENSICS.
```
