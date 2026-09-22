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
