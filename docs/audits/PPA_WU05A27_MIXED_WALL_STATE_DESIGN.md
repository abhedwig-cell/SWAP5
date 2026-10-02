# A27 mixed wall physical/state design boundary

Date:2026-10-02. Status: OWNERSHIP_SELECTED_RESEARCH_ONLY; PRESSURE_SEAM_REFINEMENT_BLOCKED. This is a concrete continuation boundary following the [actual constitutive domain result](PPA_WU05A27_REAL_HYDRAULICS_RESULT.md), not a new accepted production contract.

## Selected A27 research ownership

A27 now selects the auxiliary-shape option for research continuation. Reference Richards remains the sole owner of matrix water storage. Any lateral wall profile may carry shape/history but owns no additional matrix water volume and cannot be added to the unchanged Richards storage ledger. The finite receiver may own its own explicitly separate macropore storage. Saturated pressure is taken from the accepted Reference head as separate authority.

This selection avoids repartitioning the production Richards matrix volume while the wall closure is still under falsification. It is not a universal production decision. The explicit-volume alternative would require a deliberate repartitioning of the Reference matrix ledger and its own admission work.

The first reciprocal pressure/receiver seam under this ownership is documented in [PPA_WU05A27_PRESSURE_RECEIVER_RESULT.md](PPA_WU05A27_PRESSURE_RECEIVER_RESULT.md). It passes mass ownership, signed direction, moving-contact exercise and reject/replay checks, but fails preregistered matrix-refinement behavior. Therefore the ownership decision is retained while the moving-contact exchange formulation remains unqualified.

## Variables and physical residual

For a homogeneous horizontal wall stratum, let theta=theta(h) be the physical retention relation and define pressure Kirchhoff potential U(h)=integral K(v)dv from a fixed datum. Darcy is q=-dU/dx. Where h(theta) is unique, dU/dtheta=K*dh/dtheta and the unsaturated diffusion representation follows. At saturation with no physical elastic storage, theta stays constant but U(h)=U(0)+Ks*h continues to carry pressure gradients. The general unknown must therefore preserve pressure information through saturated regions; it cannot rely only on invertible theta.

For each trial wall cell use physical mass residual V_i*(theta(h_i_trial)-theta(h_i_accepted))-dt*(owned inflow_i-owned outflow_i)=0. Source solver capacity floors may appear only in a declared numerical Jacobian/regularization policy, not in that physical residual, the retention law or U. A genuine elastic-storage option requires its own physical parameter/admission authority; no arbitrary saturated storage is introduced here.

For a finite receiver, use R_trial-R_accepted-external_receipt+sum(wall_exchange)+owned_other_release=0. Determine hydrostatic head/wet contact from the same trial receiver state. Positive and reverse wall exchange appear with opposite signs in the two owners. Do not cap away reverse flow or saturated through-flow merely to keep a moisture inversion defined.

## Geometry, bounds and state ownership

The research representation should use fixed vertical wall patches and fixed lateral cells; wetted fractions derive from water level. Retain moisture/pressure history in cells on absent contact under an explicit physical drying boundary; no automatic dry reset. This is a finite-grid approximation to partly wet patches, not exact reconstruction of arbitrary subpatch histories. Grid refinement must test newly wetted, partially wet, draining and repeatedly interrupted patches, with the same grid policy for every case.

For A27 research the auxiliary-shape contract is selected: the profile has no independently counted matrix storage and its mean/shape must remain consistent with the authoritative Reference matrix state. The explicit wall-subvolume alternative remains a distinct future model contract and is not mixed into this route. **Do not combine independent slab storage with an unchanged full-volume Richards ledger and count both.** The selected research ownership is not production-qualified.

Trial pressure/profile state and receiver candidates remain unpublished until acceptance; discard/replay must preserve accepted arrays. A profile trial cannot silently modify actual Richards state, use stale wall geometry on successful acceptance, or consume the external top input a second time. MB deep receipt remains distinct from matrix qbot; leading MB has no passage wall exchange.

## Prospective gates before production work

The volume/mean ownership is now fixed to the auxiliary no-independent-storage option for A27 research. The next contract must first specify a physically consistent saturated/seep moving-contact conductance transition, material parameters, geometry mapping and sampling **before** another coupled experiment. It must test saturated steady Darcy from the36-material source counterexamples, mixed unsaturated/saturated transitions, reverse exchange, moving partial contact and physical drying, with conserved receiver/matrix mass and rejected-trial immutability. Compare physical residuals using exact retention derivatives versus numerical regularization without allowing a changed storage law. Separate physical closure resolution from explicit/subcycled/coupled execution policy.

The previous128-cell count is a research comparator, not a default. No prediction of speedup or production-equivalent behavior is authorized by this design. Current A26, standard macropore and full Reference production sources remain untouched. Full A/B/C and central canonical admission are still separate gates.
