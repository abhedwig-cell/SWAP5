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
