# F-PE-NLGLOB14Z30 result — trajectory-driving adaptive manager A/B benchmark

Date: 2026-09-30

Status:

`DRIVING_ADAPTIVE_DIVERGENCE`

Qualification authority:

- workflow run: `36739588440`;
- HEAD segment-B job: `109974727012`;
- RUNOFF segment-B job: `109974727001`;
- workflow conclusion: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@38b78b3415cee0563eb19efa68b73a6082b3c899`

The canonical delta since the Z30 baseline is confined to ELASTIC70 closeout documentation and does not touch the Z30 dependency surface.

Research postimage before result persistence:

`research/f-pe-nlglob14z30-driving-manager-ab@73f1e0f619fd0d3ffd738a5cf472ef4fec816df0`

## Frozen aggregate result

Both fine O05 fixtures classify:

`DRIVING_ADAPTIVE_DIVERGENCE`.

The reason is narrow and identical in character for both routes:

the preregistered cumulative mass-difference gate of `5e-7 cm` is exceeded after more than 2.1 million independently driven adaptive intervals.

No threshold is widened.

## HEAD

- accepted adaptive intervals before gate: `2,142,783`;
- stop time: about `273.92394 d`;
- final tail at stop:
  - full: `13:16`;
  - adaptive: `13:16`;
- ownership event sequence identical through stop;
- max head divergence: about `4.255e-5 cm`;
- max theta divergence: about `2.211e-8`;
- max top-flux divergence: about `1.441e-10 cm/d`;
- max per-interval ledger difference: about `1.414e-9 cm`;
- max adaptive per-interval ledger: about `1.241e-9 cm`;
- cumulative mass difference at stop: about `5.00037e-7 cm`.

Adaptive/full deterministic work ratio:

`0.75968`.

Mean adaptive active dimension:

`12.097`.

Dimension occupancy:

- n=12: 1,934,939 intervals;
- n=13: 207,844 intervals.

## RUNOFF

- accepted adaptive intervals before gate: `2,137,836`;
- stop time: about `273.61475 d`;
- final tail at stop:
  - full: `13:16`;
  - adaptive: `13:16`;
- ownership event sequence identical through stop;
- max head divergence: about `4.192e-5 cm`;
- max theta divergence: about `2.426e-8`;
- max top-flux divergence: about `8.505e-11 cm/d`;
- max per-interval ledger difference: about `1.409e-9 cm`;
- max adaptive per-interval ledger: about `1.280e-9 cm`;
- cumulative mass difference at stop: about `5.00585e-7 cm`.

Adaptive/full deterministic work ratio:

`0.75950`.

Mean adaptive active dimension:

`12.095`.

Dimension occupancy:

- n=12: 1,934,888 intervals;
- n=13: 202,948 intervals.

## Preserved physics before stop

Across both routes before the cumulative gate is reached:

- both trajectories remain finite;
- saturated-tail geometry remains contiguous;
- one-face ownership motion is preserved;
- the ordered ownership-event sequence is identical;
- the local chatter sequence is reproduced;
- provider route remains surface-flux;
- final tail at stop matches;
- no adaptive reconstruction failure occurs;
- no adaptive nonlinear solve failure occurs;
- no event-direction contradiction occurs;
- all instantaneous h/theta/top-flux comparison gates remain inside their frozen bounds.

## Performance signal

Despite the negative aggregate classification, the work signal is strong.

The adaptive trajectory uses about:

- 75.97% of full deterministic solver work for HEAD;
- 75.95% for RUNOFF.

That corresponds to approximately 24% lower deterministic nonlinear algebra work over more than two million accepted intervals.

This is a trajectory-level result, not merely an event-window result.

## Interpretation

Z30 does not falsify the moving-interface manager architecture.

It falsifies only the claim that the current reduced trajectory remains inside the preregistered cumulative mass-difference envelope through 540 d.

The failure is small in absolute magnitude and occurs only after prolonged independent integration.

The available evidence is consistent with two possibilities that Z30 itself does not distinguish:

1. a systematic reduced-tail mass bias accumulating every interval;
2. accumulation of very small numerical differences with little or no systematic physical bias.

That distinction must be made before changing any tolerance or proceeding to production admission.

## Qualified claim boundary

Qualified:

- independent adaptive driving for more than 2.1 million intervals;
- correct moving-interface event sequence through stop;
- instantaneous physical differences within frozen gates;
- no reconstruction or solve failure;
- about 24% deterministic work reduction;
- cumulative mass-difference gate eventually exceeded.

Not qualified:

- 540 d long-horizon adaptive equivalence;
- production admission;
- tolerance relaxation;
- end-to-end production wall-clock speedup.

## Consequence

Open a separately preregistered drift-attribution successor.

That successor must determine whether the cumulative mass difference is:

- monotone/systematic;
- event-localized;
- ownership-regime dependent;
- or approximately zero-mean numerical accumulation.

It must not relax the `5e-7 cm` Z30 gate retroactively.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
