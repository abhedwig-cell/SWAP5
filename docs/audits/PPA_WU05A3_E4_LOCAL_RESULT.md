# PPA-WU05-A3 E4 local crack-history result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / H5_HISTORY_ACTIVE / NOT_YET_QUALIFIED`

## Question

Does `VlMpDyCp` merely reflect current matrix moisture, or does prior crack state materially affect the next dynamic macropore volume?

## Source authority

Exact B1.11 `MPVOLUME`, `macropore.f90:1728-1755`.

The branch condition is:

- if moisture is increasing and the current or neighbouring compartment already has dynamic crack volume, use `ThetaS` as crack-closing threshold;
- otherwise use `ThetCrMp`.

Thus the next crack state can depend on prior `VlMpDyCp` even when current `Theta` and `ThetaM1` are identical.

## Local experiment

Identical current conditions:

- current `theta = 0.35`;
- previous-step `theta_m1 = 0.30` (wetting);
- `theta_cr = 0.30`;
- `theta_s = 0.45`;
- identical shrinkage relation and geometry.

Only crack history differs.

### Fresh/no-crack history

`prior_crack = 0`, no cracked neighbour.

Result:

`VlMpDyCp = 0`.

Reason: the active threshold is `ThetCrMp = 0.30`, and current theta is above it.

### Existing local crack

`prior_crack = 0.08 cm`.

Result:

`VlMpDyCp ~= 0.30928 cm`.

The active threshold switches to `ThetaS = 0.45`, so the same current theta remains in the cracked branch.

### Existing neighbouring crack

Local prior crack = 0, neighbouring crack = `0.08 cm`.

Result:

`VlMpDyCp ~= 0.30928 cm`.

## Interpretation

The same current hydraulic state yields qualitatively different dynamic crack volume solely because of prior/nodal crack history.

Therefore `VlMpDyCp` is not a disposable derived view of current theta. It carries real hysteretic continuation information.

This independently supports A1/A2 classification of `VlMpDyCp` as committed physical/history state.

## H5 disposition

The broad H5 statement that crack history is materially active only in identifiable shrinkage regimes remains open, but the first half is demonstrated:

`CRACK_HISTORY_IS_PROCESS_ACTIVE_IN_WETTING_TRANSITION_REGIME`.

## Next step

E5 should isolate rapid-drain activation and test whether its threshold response is continuous and uniquely externally owned. E6 can then address the corrected saturated/unsaturated interface index.
