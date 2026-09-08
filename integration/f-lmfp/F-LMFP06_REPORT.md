# F-LMFP06: Heterogeneous Interface Physics & Darcian-Mean Reference

## Decision

`QUALIFIED_DARCIAN_REFERENCE_AND_LOOKUP_FEASIBILITY_READY_FOR_TRANSIENT_CANDIDATE_AB`

This workunit does not admit a production solver change. It establishes a steady hydraulic reference, diagnoses the remaining LayeredMFP face-closure error, and demonstrates that a shared precomputed Darcian lookup is a credible reduced-order mechanism worth testing in a transient column.

## Base

F-LMFP06 starts from the qualified F-LMFP05 closeout:

`d53719b31202f73b621afce71b107699a0000737`

F-LMFP05 had already shown that the persistent LayeredMFP versus FullRichards offset on the original coarse grid is dominated by the internodal flux closure. It also showed that homogeneous arithmetic-K and MFP closures converge toward each other under grid refinement, whereas a true material discontinuity retains a distinct series-resistance limit.

## Independent steady-Darcy oracle

A diagnostic oracle was added in:

`experiments/lmfp/run_lmfp06_darcian_reference.py`

The oracle uses the same SWAP-compatible constitutive K(h) functions as the testbench, but it does not call a LayeredMFP face routine and it does not use a conductivity averaging rule. For each local face problem it solves the steady one-dimensional Darcy boundary-value problem with:

`q = K(h) * (1 - dh/dz)`

using z and q positive downward. The same conservative q is integrated through the complete local domain. For heterogeneous faces the pressure head is continuous at the material interface. The numerical implementation uses shooting on q with adaptive RK4 integration inside each material segment.

Analytic checks cover:

- equal pressure heads in a homogeneous material, for which q = K(h);
- a hydrostatic pressure-head gradient, for which q = 0;
- tolerance tightening of selected independent-oracle cases.

The maximum flux change in the explicit tolerance-reproducibility check was `6.37e-11 cm/d`.

## Heterogeneous local interface result

For the F-LMFP05 sand-clay interface around h = -90 cm, refined to a total node distance of 0.3125 cm, the independent BVP gives:

| orientation | q reference cm/d | q LayeredMFP cm/d | MFP rel. error | harmonic rel. error | arithmetic rel. error |
| --- | ---: | ---: | ---: | ---: | ---: |
| sand to clay | -0.00782559 | -0.00780528 | 0.260% | 0.227% | 57.8% |
| clay to sand | -0.00782502 | -0.00780587 | 0.245% | 0.230% | 60.7% |

This independently confirms the F-LMFP05 conclusion that the local equal-flux material-interface construction approaches the expected series-resistance behaviour. The arithmetic endpoint mean is not an appropriate unique physical reference for this discontinuity.

## Broad face matrix

The first independent matrix contains 240 deterministic-random cases over:

- homogeneous sand;
- homogeneous clay;
- sand over clay;
- clay over sand;
- variable pressure heads;
- variable upper and lower half-distances.

No oracle solve failed. No tested MFP, arithmetic, or harmonic closure reversed the reference flow direction.

Relative flux error against the steady-Darcy oracle was:

| closure | median | p90 | maximum |
| --- | ---: | ---: | ---: |
| LayeredMFP MFP | 2.64% | 20.2% | 72.9% |
| arithmetic endpoint K | 258% | 8996% | 95007% |
| harmonic endpoint K | 53.5% | 98.2% | 143% |

The large remaining MFP errors are not concentrated at heterogeneous material interfaces. They are dominated by homogeneous sand under large vertical pressure-head gradients. That diagnosis changes the next design question: the main unresolved face physics is the interaction between capillary conductivity variation and gravity in a coarse vertical block.

## Szymkiewicz 2009 formula control

A separate literature-formula control was added in:

`experiments/lmfp/run_lmfp06_szym2009_control.py`

It implements the three homogeneous vertical-flow regimes described by Szymkiewicz (2009): downward flow into drier soil, downward drainage or infiltration near a water table, and upward capillary flow. This control is deliberately limited to homogeneous faces.

It is not called `SWKMEAN=7`, because the historical SWAP table generator and its generated `.unf` data are not present in the supplied SWAP 4.3.1 source archive.

Across 260 homogeneous cases:

| metric | current MFP secant | Szymkiewicz-2009 control |
| --- | ---: | ---: |
| median relative error | 5.32% | 3.23% |
| p90 relative error | 32.5% | 18.3% |
| maximum relative error | 209% | 45.3% |

The Szymkiewicz control was closer to the independent oracle in 76.2% of cases.

The improvement is regime-dependent:

| regime | MFP p90 | Szymkiewicz p90 |
| --- | ---: | ---: |
| downward, dry | 32.1% | 18.1% |
| downward, wet | 8.91% | 17.1% |
| upward capillary | 45.2% | 19.6% |

So the 2009 approximation is useful evidence that vertical Darcian averaging addresses the identified problem, but it is not a universal replacement for the present closure.

In six targeted strong-gradient controls it was closer to the independent oracle than the current MFP closure in all six. For the earlier worst sand case, the MFP error of about 72.9% fell to about 7.38%.

## Historical SWKMEAN=7 provenance

The supplied SWAP 4.3.1 source contains:

- `functions.f90`, where `SWKMEAN=7` calls the Szymkiewicz route;
- `MOD_Kavg_Szym.f90`, which reads a precomputed table and performs bilinear interpolation in upper and lower pressure head.

The table has the logical shape:

`K_Szym(boundary, htop, hbot)`

and the runtime validates the compartment count, soil-layer mapping, profile identity, and compartment thicknesses against the table metadata. The expected file pattern is:

`Kavg_Szymkiewicz_<profile>_<numnod>.unf`

No such table and no table-generation program were found in the supplied source archive. Therefore this workunit does not claim numerical reconstruction of the historical `SWKMEAN=7` dataset.

The source architecture is nevertheless informative: it treats the steady-Darcian calculation as preparatory work and reduces production-time use to a table lookup.

## Oracle-derived lookup feasibility

To test that architectural idea independently, F-LMFP06 generates a diagnostic immutable 2D K_DAR table directly from the new steady-Darcy oracle and then uses bilinear interpolation only. The experiment is in:

`experiments/lmfp/run_lmfp06_lookup_surrogate.py`

This is not a copy of the historical table. It is an independently generated surrogate with only 16 x 16 head points.

Validation against fresh oracle solves gives:

| face class | median error | p90 error | maximum error | direction mismatches |
| --- | ---: | ---: | ---: | ---: |
| sand-sand, 5 cm + 5 cm | 3.34% | 11.1% | 26.7% | 0 |
| sand-clay, 5 cm + 5 cm | 2.14% | 7.03% | 20.8% | 0 |

A 16 x 16 table contains 256 double-precision values, or 2048 bytes before metadata. This number is only illustrative. Production table density and head coverage have not been selected or qualified.

The result is sufficient for feasibility: a face-specific Darcian lookup can represent both homogeneous gravity-sensitive flow and a material interface without solving the steady BVP during each transient timestep.

## Architectural interpretation for SWAP5

A Darcian lookup must not recreate the legacy kernel-I/O dependency. The solver should not open `.unf` files or know filenames.

If this route survives transient qualification, the intended SWAP5 composition is:

- generation or loading outside the soil-water kernel;
- immutable hydraulic lookup data referenced by ID;
- sharing by compatible material-pair and geometry class, or by a model-template face class;
- no table state duplicated per logical column;
- no additional committed dynamic state;
- O(1) interpolation in a trial solve;
- reference Richards mode retained unchanged;
- mass conservation enforced by the same transactional column balance as for other face closures.

This is compatible with compact persistent state, optional functionality scaling with use, homogeneous MultiSWAP templates, worker-local scratch, and the requirement that alternative soil-water solvers remain behind a common interface.

## What is not qualified

F-LMFP06 does not establish:

- that the historical SWKMEAN=7 binary tables have been reproduced;
- that 16 x 16 is a sufficient production table density;
- that Darcian lookup is more accurate than FullRichards for transient problems;
- that the lookup preserves acceptable transient mass and state trajectories;
- behaviour near saturation outside the tested head envelope;
- root uptake, drainage, ponding, groundwater, MODFLOW coupling, or crop interaction;
- production speedup or memory cost at MultiSWAP scale;
- a final choice between direct approximate formulas and precomputed exact-Darcian tables.

## Literature lineage

The source comments and the reconstructed controls are consistent with:

1. Warrick, A.W. (1991). Numerical approximations of darcian flow through unsaturated soil. Water Resources Research. DOI: 10.1029/91WR00093.
2. Szymkiewicz, A. (2009). Approximation of internodal conductivities in numerical simulation of one-dimensional infiltration, drainage, and capillary rise in unsaturated soils. Water Resources Research 45. DOI: 10.1029/2008WR007654.
3. Szymkiewicz, A. and Helmig, R. (2011). Comparison of conductivity averaging methods for one-dimensional unsaturated flow in layered soils. Advances in Water Resources 34(8), 1012-1025. DOI: 10.1016/j.advwatres.2011.05.011.

The literature treats the Darcian mean as the conductivity that makes the discrete internodal Darcy flux equal to the local steady-flow solution. It also distinguishes homogeneous internodes from layered cell-centered interfaces, which is why this workunit keeps the 2009 homogeneous formula control separate from the two-material BVP.

## Next workunit

F-LMFP07 should be a transient candidate A/B workunit, still outside production code.

The smallest useful test is:

1. construct immutable Darcian lookup providers for the existing F-LMFP04 hydraulic fixtures;
2. run the same generic-time mass-conservative LayeredMFP column with the old MFP face closure and the new lookup closure;
3. compare both against the admitted FullRichards path on the same initial state and forcing;
4. include the strong homogeneous vertical-gradient cases exposed in F-LMFP06;
5. report storage, node water content or head, top and bottom flux, mass residual, timestep sensitivity, lookup coverage, and cost diagnostics;
6. do not yet add crop, drainage, ponding, groundwater, or MODFLOW coupling.
