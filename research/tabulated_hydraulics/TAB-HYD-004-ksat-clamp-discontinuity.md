# TAB-HYD-004: default-MvG Ksat clamp creates a finite conductivity jump

Date: 2026-09-20

Status: **REPRODUCED / PUBLIC-TRANSITIONAL LINEAGE / RESEARCH FINDING**

This finding is not a production patch and is not yet an exact SWAP 4.3.1 B0 claim.

## Observation

In the default analytical MvG residual, `hconduc` returns `Ksat` when relative saturation exceeds

`Se = 1 - 1e-6`.

Immediately below that threshold, the ordinary Mualem-van Genuchten conductivity is used. Those two values are not generally close. The implemented residual therefore contains a finite jump in K for parameterizations where the ordinary MvG curve is still appreciably below Ksat at `Se=1-1e-6`.

TAB-HYD-003 corrected the derivative on the already constant Ksat branch. TAB-HYD-004 is different: it concerns the **residual K function itself**, not merely its Jacobian.

## Staring-series scan

The implemented threshold was evaluated for all 30 parameter rows in the checked StaringSeries1994 authority.

- 21 of 30 classes have a Ksat / K-below ratio of at least 1.05.
- 9 of 30 have a ratio of at least 1.25.

Largest jumps include:

| soil | K immediately below clamp | Ksat | Ksat / Kbelow |
| --- | ---: | ---: | ---: |
| B12 | 5.00083 | 15.46 | 3.09149 |
| O13 | 1.53603 | 3.32 | 2.16142 |
| B11 | 2.45674 | 5.26 | 2.14105 |
| B17 | 2.59551 | 4.46 | 1.71835 |
| O11 | 8.58341 | 13.79 | 1.60659 |
| O6 | 3.41098 | 5.48 | 1.60658 |

For B12 the threshold occurs at approximately `h=-5.82e-4 cm`. The residual changes from about `5.00 cm/d` immediately below the threshold to `15.46 cm/d` above it.

## Consequence for the first direct-table candidate

The preregistered 250-row table candidate used one smooth log(K) spline from the dry end to the final h=0/Ksat endpoint. A continuous spline cannot reproduce a finite residual jump exactly. It necessarily bridges the jump over an interval.

Direct comparison of the actual table derivative against the corrected analytical residual shows the effect clearly:

- B12 analytical maximum sampled |dK/dh|: about `1.19e3`;
- B12 table maximum sampled |dK/dh|: about `3.92e4`;
- B12 maximum relative K error in the derivative-shape scan: about `0.710`;
- the denser table-only scan also found a locally **negative dK/dh**, minimum about `-19.85`, despite monotone K knots.

For O13:

- analytical maximum sampled |dK/dh|: about `90.5`;
- table maximum sampled |dK/dh|: about `1.88e3`;
- maximum relative K error: about `0.534`.

The same effect is milder for B4/O5 and intermediate for B9/O9.

## Relation to the failed broad envelope

The non-fail-fast envelope diagnostic shows that the original direct-TSPACK candidate is already non-equivalent under `SWKIMPL=0` for the affected hydraulic regimes:

- B12/O13 clay-wet case: GWL max difference about `105.51 cm`;
- B9/O9 loam-mid case: GWL max difference about `1193.94 cm`;
- coarse B4/O5 cases: GWL max difference only about `1.3e-4 cm`;
- loam-capillary case: GWL max difference about `2e-5 cm`, because the realized trajectory does not expose the same error strongly.

This pattern is consistent with a representation problem that is strongly state- and parameter-dependent. It must not be interpreted as a generic failure of tables. It specifically invalidates the first **single-spline conductivity representation** as a faithful surrogate for the implemented analytical residual across the preregistered envelope.

## Research implication

A faithful lookup representation of the current residual must preserve the branch structure instead of smoothing across it. For generated MvG acceleration tables, the natural next candidate is therefore:

1. interpolate the continuous sub-threshold K branch only;
2. retain the Ksat plateau as an explicit branch;
3. return dK/dh=0 on the plateau;
4. keep theta/C interpolation independent of this K branch split;
5. use direct O(1) interval indexing within the continuous branch.

A research-only branch-aware candidate is being tested separately. Passing that diagnostic would not make the preregistered envelope pass retrospectively.

## Authority boundary

The source behavior and executable evidence here are bound to the public/transitional SWAP lineage used by TAB-HYD. Exact supplied SWAP 4.3.1 B0 remains controlled by the canonical archive hashes and has not been executed in this workstream.
