# Proposed explicit Darcy entry transition

HIST-INTEGRATION01, baseline362cf65f; diagnostic draft641e0185. Not admitted.
The original MACRORATE condition has a finite unsaturated Darcy-rate jump at
`entry_head-1e-8cm`. Actual native execution approaches this threshold with
roughly1e-14day accepted increments. The standard historical equation remains
available with width zero and must retain exact production-leaf output.

This proposed opt-in physical regularisation multiplies only the Darcy head
difference by a cubic smoothstep over `[threshold-width,threshold]`. Outside
that interval the original Darcy head difference is exact; endpoints have
continuous zero/one gate and zero gate slope. The existing max with sorptivity,
limiter, macro stock update, matrix source and all transactional/mass/temporal
contracts remain. The production Jacobian uses the derivative of that same gate.
Width is an explicit finite physical input in `(0,1e-3]cm`; zero is the default.
Native selection is explicit, bound into the existing input/executable restart
identity. This is a corrected-source variant, never exact4.3.1 equivalence.

Select first actual O0/O2 rate and Jacobian controls, including width-zero
preservation, exterior identity, finite-difference slope and invalid widths.
Then select the original two-day112-node/five-domain macro/Rutter/heat/root/drain
application, independent supplied-source water budget and real file restart.
A second1e-5cm width may check whether a completed1e-4cm result depends materially
on the transition width; it does not alter temporal tolerance(.01) or mass(1e-10).
No seasonal claim, broad F-CI, low-air, RossFast or new1e-6 accuracy probe.
