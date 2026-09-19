# TAB-HYD-002: documented PCHIP interpolation does not match the current public table engine

Status: **CONFIRMED DOCUMENTATION-CODE DISCREPANCY ON CURRENT PUBLIC LINEAGE**

Scope: research finding only. No production change is admitted here.

## Documentation statement

The current SWAP theory and user guide, section 2.2.3 "Soil hydraulic functions as tables", states that tabulated theta(h) and K(h) are interpolated using piecewise cubic Hermite interpolation with the public-domain SLATEC PCHIP routines, preserving monotonicity.

The current online guide is the June 2026 guide associated with the SWAP 4.3 generation.

## Current public implementation

In `SWAP-model/SWAP@c22bd832ddf3e53e330a552f5e31e74f183362d1`, `src/soil/sptabulated.f90` contains both interpolation implementations but activates:

```fortran
logical, parameter :: use_TSPACK = .true.
```

The active forward evaluation calls the TSPACK tension-spline functions `my_HVAL` and `my_HPVAL`.

The SLATEC/PCHIP path is still present behind the inactive `use_TSPACK=.false.` branch. It is therefore not merely a terminology difference in the manual: the documented algorithm and the compiled current-public algorithm are different.

## Executable comparison

The dormant PCHIP route was activated without otherwise changing the table data or Hupsel `SWKIMPL=0` setup.

For the full 2002-2004 daily Hupsel experiment:

- active TSPACK vs analytical MvG:
  - GWL max absolute difference = `0.00018 cm`;
  - GWL RMSE = `6.80e-6 cm`;
- dormant PCHIP vs analytical MvG:
  - GWL max absolute difference = `0.25985 cm`;
  - GWL RMSE = `0.007865 cm`;
  - DRAINAGE max absolute difference = `0.00025 cm`;
  - DSTOR max absolute difference = `0.00024 cm`.

Thus the algorithm choice is behaviorally observable even for a dense table generated from the same analytical constitutive relation.

## Performance comparison

A 12-round repeated benchmark produced median full-run times of approximately:

- analytical MvG: `0.7154 s`;
- active TSPACK table route: `0.8157 s`;
- dormant PCHIP table route: `0.8155 s`.

The PCHIP route was effectively the same speed as TSPACK in this experiment and about 14% slower than the analytical route. Simply restoring the documented PCHIP switch is therefore not an acceleration route.

## Interpretation

The current documentation should not be used as authority for the interpolation algorithm actually executed by the current public code.

For any future fast-table design, the acceptance baseline must be stated explicitly:

1. preserve current executable TSPACK behavior;
2. preserve the documented PCHIP behavior;
3. or define a new interpolation contract and qualify its hydrological response.

These are not interchangeable because the Hupsel experiment shows measurable trajectory differences.

## Authority boundary

This finding is source-bound to the current public implementation and current online documentation. Exact supplied SWAP 4.3.1 B0 source execution remains a separate authority gate because the raw B0 archive is not materializable in the present workstream.
