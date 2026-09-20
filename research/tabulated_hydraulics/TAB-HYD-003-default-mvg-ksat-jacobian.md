# TAB-HYD-003: default MvG Ksat clamp is inconsistent with the SWKIMPL=1 Jacobian

Status: **CONFIRMED CURRENT/PUBLIC IMPLEMENTATION DEFECT; RESEARCH CANDIDATE QUALIFIED ON HUPSEL**

Scope: research finding only. No B1 or SWAP5 production admission is made by this document.

## Finding

The default analytical Mualem-van Genuchten conductivity route contains an explicit near-saturation residual clamp.

For the branch with `h_enpr > -0.01 cm`, `hconduc` returns `Ksat` when relative saturation exceeds `1 - 1e-6`.

The corresponding `dhconduc` route does not apply that same branch condition. It continues to evaluate the unclamped Mualem-van Genuchten derivative until relative saturation exceeds the separate `s_enpr` condition.

Therefore, over a finite near-saturated state interval:

- the residual uses a constant `K(h) = Ksat`;
- the implicit Jacobian uses a non-zero and increasingly steep derivative of a different, unclamped K relation.

This violates the same residual/Jacobian consistency rule established for SWAP-011: the derivative used in the Newton Jacobian must differentiate the conductivity relation actually used in the residual.

## Direct executable evidence

The current-public hydraulic wrappers at
`SWAP-model/SWAP@c22bd832ddf3e53e330a552f5e31e74f183362d1`
were evaluated for the Hupsel topsoil parameters.

Representative points:

| h (cm) | K used by residual (cm/d) | code dK/dh | finite-difference derivative of implemented K(h) |
| ---: | ---: | ---: | ---: |
| -0.008 | 12.1073655 | 16.841824 | 16.841810 |
| -0.007 | 12.1249735 | 18.433338 | 18.433424 |
| -0.005 | 12.52 | 23.139614 | 0 |
| -0.001 | 12.52 | 68.508941 | 0 |

The two points inside the Ksat clamp show the defect directly: the residual function is locally constant while the Jacobian derivative is non-zero.

The probe also shows a separate derivative discontinuity at the `h=-0.01 cm` constitutive transition. That boundary deserves separate treatment and is not needed to establish the Ksat-clamp mismatch.

## End-to-end consequence

A full 2002-2004 Hupsel experiment was run with daily output.

Unmodified analytical routes:

- `SWKIMPL=0` completed;
- `SWKIMPL=1` completed, but its trajectory diverged severely from the `SWKIMPL=0` control;
- GWL maximum absolute difference = `1146.52418 cm`;
- GWL RMSE = `1091.56561 cm`.

A research-only candidate changed only the analytical Jacobian in the already-clamped Ksat branch to `dK/dh=0`. It did not change theta(h), K(h), forcing, boundaries or `SWKIMPL=0`.

With that candidate:

- analytical `SWKIMPL=1` versus analytical `SWKIMPL=0`:
  - GWL max abs = `0.62579 cm`;
  - GWL RMSE = `0.0434817 cm`;
  - DRAINAGE max abs = `0.00732 cm`;
  - DSTOR max abs = `0.00733 cm`;
  - TACT max abs = `0.00266 cm`.

The corrected analytical `SWKIMPL=1` route and the independently endpoint-corrected table `SWKIMPL=1` route then agreed very closely:

- GWL max abs = `0.00043 cm`;
- GWL RMSE = `1.54e-5 cm`;
- DRAINAGE and TACT matched at written output precision;
- DSTOR max abs = `1.41e-10 cm`.

This triangulation is stronger than either table-only or analytical-only evidence. Both constitutive representations converge to essentially the same implicit trajectory after their residual/Jacobian branch inconsistencies are removed.

## Relationship to TAB-HYD-001

TAB-HYD-001 concerns the table endpoint policy:

- K is held constant at table endpoints;
- the wet derivative was set to `1e8`;
- the dry derivative could evaluate outside the table.

TAB-HYD-003 shows that the analytical default-MvG route has an analogous near-saturation inconsistency. This explains why the previously used unmodified analytical `SWKIMPL=1` trajectory was not a valid acceptance reference for judging the corrected table `SWKIMPL=1` route.

The table endpoint zero-derivative candidate is therefore supported by two independent facts:

1. it differentiates the constant endpoint K branch actually used by the table residual;
2. after the analogous analytical Ksat-clamp derivative is made consistent, analytical and table `SWKIMPL=1` trajectories agree to very small tolerances.

## Authority boundary

The direct wrapper evidence is bound to the current public source lineage and the end-to-end evidence to the pinned pre-strangler executable lineage.

The exact supplied SWAP 4.3.1 B0 archive remains the historical authority. Its raw source archive cannot currently be materialized through the available Project-file path, so this document does not claim byte-exact B0 reproduction.

The current SWAP5 default-MvG provider still carries the same residual Ksat clamp, but F-SI09 deliberately does not admit `SWKIMPL=1` and currently returns zero in the reserved `dconductivity_dhead` output. TAB-HYD-003 therefore does not describe a presently admitted SWAP5 production failure. It is a required consistency condition before an implicit-conductivity derivative route is admitted.

## Candidate correction

The bounded candidate is to mirror the residual Ksat clamp in the analytical derivative branch:

```fortran
if (h_enpr > h_crit .and. relsat > 1.0 - 1.0e-6) then
   dhconduc = 0
else
   ... existing derivative ...
end if
```

This is not a change to the hydraulic constitutive relation. It makes the Jacobian derivative consistent with the already-implemented residual relation.
