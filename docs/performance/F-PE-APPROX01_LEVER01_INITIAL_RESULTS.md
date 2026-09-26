# F-PE-APPROX01 Lever01 initial tangent frontier

Date: 2026-09-26

Status: `INITIAL_LOCAL_FRONTIER`

Branch:
`work/f-pe-approx01-tangent-cadence`

Parent exact authority:
`F-PE-DIR01@584af6ce2e6e4a6cd2c790e6341805e56085127b`

## Measurement level

The first participant-level sequence experiment was rejected as a measurement vehicle because the production groundwater transaction gate correctly rejected prescribed-head correctors away from the exact equilibrium point in the short FGC44 fixture.

The second full-half transaction sweep was likewise too restrictive for mapping the local tangent function.

The accepted measurement therefore moves one layer lower without changing the physics:

- exact Reference Richards solve;
- exact bottom-head boundary;
- exact accepted-step directional service;
- identical initial physical state for every head point;
- no transaction acceptance approximation.

This measures the local tangent function that the coupling participant ultimately consumes.

## Sweep

For each initial pressure-head regime:

- wet: `h=-10 cm`;
- mid: `h=-75 cm`;
- dry: `h=-500 cm`;

the prescribed bottom head was swept over approximately `±0.5 cm`.

Every point converged and produced an available production bottom-head tangent.

## Tangent variation

### Wet

Tangent range:

`2.5940434 ... 2.5989343`

Full ±0.5 cm span:

approximately `0.004891`.

Relative variation across the sweep is only about `0.19%`.

### Mid

Tangent range:

`0.3147945106 ... 0.3147966916`

Full span:

approximately `2.18e-6`.

Relative variation is of order `7e-6`.

### Dry

Tangent range:

approximately

`2.3921630467e-3 ... 2.3921630660e-3`.

Variation is effectively negligible at this scale.

## Fixed-cadence lag error

The cadence experiment reuses the tangent sampled at the start of each block.

### lag-2

Avoided tangent evaluations:

`50%`

Maximum relative tangent error:

- wet: `4.79e-4` = about `0.048%`;
- mid: `1.73e-6`;
- dry: `2.02e-9`.

### lag-4

Avoided tangent evaluations:

`75%`

Maximum relative tangent error:

- wet: `9.52e-4` = about `0.095%`;
- mid: `3.46e-6`;
- dry: `4.03e-9`.

### lag-8

Avoided tangent evaluations:

`87.5%`

On this repeated symmetric head pattern, the maximum tangent errors are essentially the same as lag-4:

- wet: about `0.095%`;
- mid: about `3.46e-6`;
- dry: about `4e-9`.

This should not be generalized beyond the tested sweep. It results partly from the chosen head sequence.

## First-order coupling-response error

For a hypothetical additional `1 cm` bottom-head correction, the maximum error in the linearized bottom-flux response caused by tangent lag is:

### wet
- lag-2: about `1.24e-3` in native bottom-flux units;
- lag-4/8: about `2.47e-3`.

### mid
- lag-2: about `5.45e-7`;
- lag-4/8: about `1.09e-6`.

### dry
- order `1e-11` or smaller.

This is derivative-linearization error only. It is not yet an end-to-end MODFLOW head error.

## Runtime opportunity implied by DIR01 rebaseline

The post-DIR01 measured bottom-head ratio was approximately:

`directional / Reference = 1.7288`.

Thus the fresh tangent overhead is approximately:

`0.7288 × Reference`.

If a lagged iteration can run the exact Reference physical solve without rebuilding a tangent, an idealized cadence cost is:

`Reference + fresh_fraction × tangent_overhead`.

Relative to fresh tangent every evaluation, this implies approximate upper-bound speedups of:

- lag-2: about `21.1%`;
- lag-4: about `31.6%`;
- lag-8: about `36.9%`.

These are not yet measured end-to-end speedups. They are workload-derived expectations before cache/control overhead and coupled-iteration effects.

## Interpretation

Lever01 is strongly promising.

The key observation is not merely that lagging is faster in principle. It is that within the tested corrector neighborhood the bottom-head tangent is much smoother than the bottom flux itself, especially in mid and dry states.

This means a large part of the remaining directional cost may be avoidable without approximating the physical SWAP state solve.

The wet regime is the controlling case in the current sweep.

## Next experiment

Do not admit fixed cadence yet.

Next:

1. execute actual fresh-versus-lagged timing where non-refresh evaluations perform the exact Reference solve and reuse the cached tangent;
2. expand the head-amplitude sweep until the practical corrector envelope is known;
3. test additional hydraulic materials, not only the current B01-like fixture;
4. then decide whether fixed `lag-2` or `lag-4` is robust enough, or whether an adaptive refresh trigger is needed.

No production approximate mode is admitted at this stage.
