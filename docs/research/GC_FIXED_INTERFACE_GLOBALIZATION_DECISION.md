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
