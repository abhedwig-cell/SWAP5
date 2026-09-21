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

The corrector admissibility scan is asymmetric for this short 1e-4 day window: -2e-6 m is rejected with status 4, whereas -1e-6 through +2e-6 m are accepted in the sampled set. A stability experiment must not cross this physical/numerical trial envelope and then interpret rejection as divergence.

## Linearized coupling criterion

Let the true outward SWAP exchange have local slope p=dq/dH (<0 here), and let the published reanchored surrogate retain slope s=+u/dt (>0). Let the groundwater subsystem's local response be represented by an effective derivative g=dq_gw/dH after the prepared solve. The outer map stability is controlled by the combined local response, not by s alone.

PB01 removes lateral conductance and isolates storage, yielding the preregistered rho=-4 and live factor-four divergence.

F-GC44 contains lateral CHD conductance and a much shorter window. Its near-root closure cannot identify the finite-perturbation amplification because the natural first iterate is effectively at the root.

## Decision

Qualified:
- physical outward local tangent has sign -u/dt in both analytical and real-Richards evidence;
- current production-facing affine slope has sign +u/dt;
- reanchoring preserves a fixed point but does not itself guarantee stability;
- PB01 demonstrates an admissible system where the positive reanchored slope is unstable.

Not yet qualified:
- that every production groundwater regime is unstable;
- that changing HCOF globally to -u/dt is safe;
- that an explicit relaxation rule is the preferred production repair.

The architecture therefore needs an explicit distinction between physical response derivative and numerical surrogate/preconditioner. Any retained +u/dt surrogate requires a documented stability/admission envelope or an explicit globalization mechanism. It must not be documented as the physical outward exchange derivative.
