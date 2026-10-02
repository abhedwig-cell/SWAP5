# TOP03 continuum stationary-contact extension

Date: 2026-10-02. Proposed test-only extension, before execution.
Primary source: 47d76926a401253fc86fa9844ebe5c26cdc8ff55.

## Retained primary finding

The independent FV stationary solver executes 558 cases/build at O0/O2 with
exact physical numerical records. 458/468 local controls are available;
423 finite-difference response controls pass. 18 saturated whole-kernel
controls pass and all 54 inherited trajectories reproduce exactly. Only 9/18
new dynamic trajectories complete. All 24 physical comparisons are unavailable.

At H=0.005 cm, hs=-0.1 cm, R=0.5 day and m8, different starting guesses yield
two discrete roots with residuals below 1e-12 cm/day, fluxes -0.6181689011 and
-0.6196944462 cm/day, and head difference 0.0006005279 cm. At a failed m32
trajectory point H=0.005, hs=-3.229264694, R=0.5, two roots have fluxes
-4.8094925731 and -4.8116253590 cm/day. Do not repair these cases by picking a
preferred root, dropping the multistart test or smoothing K. Preserve primary
raw evidence and independently audit each competing root/profile.

## New mathematical oracle, explicitly different discretization

FV cellwise K with the actual saturation cutoff can produce discrete branch
ambiguity. Test a continuum stationary-layer integration using the identical
public constitutive K(h), actual thickness/gravity, imposed top pressure H,
and matched first-matrix-node half-cell resistance Rm=d/Ksoil(hs).
This is a new spatial oracle, not a relabeled repair of the FV equations.
The production solver, source K cutoff and outer SWKIMPL=0 policy stay fixed.

Let Es=hs-d, Ksat=L/R and downward positive infiltration J=-q.
The conductivity-saturated candidate is
Jsat=(H+L-Es)/(R+Rm), hI=Es+Jsat*Rm.
It is exact when the entire layer remains on K=Ksat, including its actual
small-negative-head saturation branch. Otherwise, J>Ksat and h decreases
monotonically down through the layer. Solve

F(J)=integral[hI(J),H] K(h)/(J-K(h)) dh - L = 0,
hI(J)=Es+J*Rm.

For this bounded inundation/monotone branch, F is strictly decreasing:
F_J=-Rm*K(hI)/(J-K(hI))-integral K(h)/(J-K(h))^2 dh < 0.
The root is bracketed between Ksat and Jsat. This supplies a conditional
single-valued scalar problem, not global uniqueness of arbitrary Richards
profiles. Preserve the K jump by splitting quadrature at the public
evaluator's actual cutoff. Use adaptive Gauss8/Gauss16 integration and
safeguarded scalar Newton, 60 iterations, 1e-12 cm length residual. Three
bracket initializations must converge to the same flux/interface. Differentiate
this same integral equation for the local response; retain branch-aware matrix
K derivatives and the true interface-head derivative in the test provider.

## Independent gates and executed extension matrix

Repeat the same 558 configurations: 18 mandatory saturated whole-kernel
controls, 468 local H/hs/R/m points and 72 six-stage trajectories. Add eight
standalone competing-FV-root points selected explicitly from the primary
failures, giving 566 cases/build. At these points expose all available FV
profiles and independently reconstruct all face fluxes and interface heads;
report branch masks and competing fluxes without choosing one.

For the continuum controls, an independent Python/SciPy Gauss-Kronrod and
Brent root evaluator must reproduce q within 1e-9 cm/day and hI within 1e-8 cm.
Its separately reconstructed synthetic B1.10 K law must match emitted public
Fortran K samples on both sides of the actual cutoff. Verify the integral
length residual <=1e-9 cm independently. In-run candidate length residual
<=1e-11 cm and matrix-face flux identity <=1e-10 cm/day remain hard gates.
Condensed response versus branch-compatible pressure perturbations uses the
previous 1e-6 absolute plus 1e-4 relative budget. Retain branch crossings as
unavailable derivatives. All valid local controls must pass, or classify the
extension before any physical decision.

The 54 inherited trajectories must remain exact. Compare O0/O2 physical
records exactly and retain raw error backtraces. Original eventwise space/time
and physical budgets are unchanged; never call finest resolution ground truth.
Whole-soil mass <=1e-10 cm and exact request-origin immutability remain hard.
No changing layer storage is added. A successful stationary closure still
needs a separately owned state/storage/receipt contract for physical dry-layer
filling. No production admission, shared interface change, new branch or CI
run is authorized. Persist this extension/source before its local execution.
