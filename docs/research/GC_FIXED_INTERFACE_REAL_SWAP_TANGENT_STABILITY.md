# F-GC44 real-SWAP tangent and stability consequence

Date: 2026-09-21
Status: LIVE LOCAL PHYSICS QUALIFIED; FINITE-PERTURBATION PRODUCTION STABILITY NOT QUALIFIED

## Evidence chain

The fixed-interface programme now has three independent observations of the same local sign structure:

1. NH01 analytical condensation: outward physical derivative = -u/dt.
2. PB01 live one-cell MODFLOW 6.8.0: -u/dt closes the exact root; reanchored +u/dt has |rho|=4.
3. F-GC44 real Richards corrector, immutable accepted origin: the measured local outward derivative is
   -3.9385817e-6 s^-1 while +u/dt is +3.9385834e-6 s^-1, ratio -0.9999996.

Therefore +u/dt is not the outward physical SWAP derivative in the qualified fixed-interface semantics.

## What F-GC44 does and does not establish

The ordinary F-GC44 live coupling closes in two iterations, but its two reported heads differ by only about 5.9e-14 m. It starts essentially at its coupled root. That run proves transaction semantics and near-root closure, not a finite basin of attraction.

The earlier claim of an asymmetric corrector-admissibility envelope was invalid. Participant status 4 means CANDIDATE_BUSY. In the historical local scan, an initial trial at href was still live when the first -2e-6 m point was called, so that point never executed the corrector. The scan's subsequent points ran only after the finally-discard cleared that candidate. The physical tangent result remains valid, but the status-4 point supplies no head-envelope evidence. A clean fresh-process G06 scan is preregistered separately.

## Linearized coupling criterion

Let the true outward SWAP exchange have local slope p=dq/dH (<0 here), and let the published reanchored surrogate retain slope s=+u/dt (>0). Let the groundwater subsystem's local response be represented by an effective derivative g=dq_gw/dH after the prepared solve. The outer map stability is controlled by the combined local response, not by s alone.

PB01 removes lateral conductance and isolates storage, yielding the preregistered rho=-4 and live factor-four divergence.

F-GC44 contains lateral CHD conductance and a much shorter window. Its near-root closure cannot identify the finite-perturbation amplification because the natural first iterate is effectively at the root.

## Decision

Qualified:
- physical outward local tangent has sign -u/dt in both analytical and real-Richards evidence;
- current production-facing affine slope has sign +u/dt;
- reanchoring preserves a fixed point but does not itself guarantee stability;
- PB01 demonstrates an admissible system where the positive reanchored slope is unstable;
- the previously reported F-GC44 -2e-6 m status-4 rejection was a candidate-lifecycle artifact, not a corrector failure.

Not yet qualified:
- that every production groundwater regime is unstable;
- that changing HCOF globally to -u/dt is safe;
- that an explicit relaxation rule is the preferred production repair.

The architecture therefore needs an explicit distinction between physical response derivative and numerical surrogate/preconditioner. Any retained +u/dt surrogate requires a documented stability/admission envelope or an explicit globalization mechanism. It must not be documented as the physical outward exchange derivative.


## G03/G05/G06 live globalization qualification

Run `35618874403` closes the first live phase-map placement and finite-start
qualification without a production-source change.

The intrinsic F-GC44 groundwater response was measured with fresh, converged
constant-flux MODFLOW probes:

[
a = dq_{gw}/dH = 2.03654572547\times10^{-2} mathrm{s^{-1}}.
]

Together with the previously qualified real-SWAP
(p=-3.93858171386\times10^{-6} mathrm{s^{-1}}), this gives

[
r=a/|p|=5170.7591.
]

F-GC44 is therefore far inside the G02 (r>3) region. The current positive
surrogate has (ho=-3.86865303\times10^{-4}), Picard has
(ho=-1.93395202\times10^{-4}), and physical Newton has (ho=0) for the
local affine problem. Measured finite-start factors at
(-1,-0.5,+0.5,+1,+2) micrometre match those predictions. P0 and P2 close in
two outer updates; P1 closes in one. The derived relaxation
(alpha^*=1/(1-ho_{P0})=0.9996132843) makes P3 one-step to numerical
precision. This is a response-derived parameter, not an empirically tuned
constant, and it is not universal across regimes.

The corrected cold-process G06 scan also establishes actual trial failures:
status 6 occurs at the sampled -5 micrometre point and more negative points,
while -2 micrometre is accepted; on the positive side +5 micrometre is
accepted and +10 micrometre fails. This is sampled asymmetry, not yet a
continuous boundary. Applying the preregistered factor-1/2 safeguard to the
nearest negative failure, -5 micrometre, produces -2.5 micrometre and an
accepted status 0 in one contraction.

Consequently, the real F-GC44 evidence now distinguishes three questions:
physical tangent sign, outer-map contraction, and corrector trial
admissibility. They are not interchangeable. The positive surrogate is
nonphysical as a derivative but is highly contractive in this particular
groundwater-response regime; PB01 remains the counterexample showing that it
can diverge in another valid regime.


## Nonlinear caveat from G04

NH03 shows why the F-GC44 local one-step Newton result cannot be generalized
without safeguarding. Exact physical Newton converges from every tested NH03
start, but one difficult start makes an excursion to `|y|=19.0598 m`.
Safeguarded Newton reaches the same root while bounding that case to the
initial `|y|=0.23 m` envelope through six factor-1/2 contractions.

This also narrows the role of relaxation. A locally derived alpha can cancel a
linear P0 error without empirical tuning, but in NH03 the difficult start
requires `alpha=3.8650`, outside an under-relaxation contract. Where the
derived alpha is admissible and exact p is known, the resulting P3 step is
algebraically Newton. Relaxation is therefore not a substitute for a
safeguard against nonlinear finite-step behavior.
