# PUB-GC E3-D2 result — whole-window predictor failure mechanism

## Status

**MECHANISM DIAGNOSED — TRANSACTION/RETRY ENVELOPE, NOT COUPLER FAILURE**

Date: 2026-09-18.

Source branch:

`work/pub-gc-e3-coupling-window-feedback-characterization`

Qualified source head:

`775554022f565e722dbc40dc6e01ecda6c3777b2`

Workflow:

`PUB-GC E3D2 predictor failure mechanism` run `35344946609` — **PASS**.

Evidence artifact:

`pub-gc-e3d2-evidence`, artifact `10546833007`, digest
`sha256:411618899c4a2f5075f423e1a03b658e6b6c14e509fff1d6c75a9df7b7ee6ba3`.

Preregistration:

`PUB_GC_E3D2_PREDICTOR_FAILURE_PREREGISTRATION.md`

## Purpose

E3-D showed that higher-flux predictor cases fail at stage 104:

```text
PREDICTOR_WHOLE_WINDOW_TRIAL_INCOMPLETE
```

before tangent construction or MODFLOW participation.

E3-D2 resolves the canonical execution mechanism at the ready/fail boundary without changing retry counts, temporal tolerances, mass tolerances, head budgets or solver settings.

## Six preregistered boundary cases

| window (day) | q predictor (cm/day) | predictor | canonical status | attempts | retries | solver rejects | temporal rejects | accepted substeps |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1e-4 | 3e-5 | READY | COMPLETED | 1 | 0 | 0 | 0 | 1 |
| 1e-4 | 1e-4 | FAIL | TRANSACTION_FAILED | 11 | 9 | 9 | 1 | 1 |
| 1e-3 | 1e-4 | READY | COMPLETED | 8 | 5 | 0 | 5 | 3 |
| 1e-3 | 3e-4 | FAIL | TRANSACTION_FAILED | 9 | 8 | 4 | 5 | 0 |
| 1e-2 | 1e-4 | READY | COMPLETED | 59 | 45 | 0 | 45 | 14 |
| 1e-2 | 3e-4 | FAIL | TRANSACTION_FAILED | 9 | 8 | 1 | 8 | 0 |

No case recorded:

- mass rejection;
- temporal-certificate-unavailable rejection.

## Interpretation

The failed predictor cases are not rejected by coupling-response assembly, tangent construction or MODFLOW. They fail because the real SWAP whole-window transaction cannot complete within the existing bounded execution policy.

The failure mechanism is not identical across windows.

At `1e-4 day, q=1e-4 cm/day`, solver rejection dominates:

```text
9 solver rejections
1 temporal rejection
9 retries
```

One half-window substep of `5e-5 day` was accepted before the transaction ultimately failed.

At `1e-3 day, q=3e-4 cm/day`, failure is mixed:

```text
4 solver rejections
5 temporal rejections
8 retries
0 accepted substeps
```

At `1e-2 day, q=3e-4 cm/day`, temporal rejection dominates:

```text
1 solver rejection
8 temporal rejections
8 retries
0 accepted substeps
```

The successful boundary cases are themselves informative. The `1e-3 day, q=1e-4` predictor required five temporal retries before completing in three accepted substeps. The `1e-2 day, q=1e-4` case required 45 temporal retries and 14 accepted substeps, with a maximum accepted temporal indicator of approximately `0.9874`, close to the active admissibility boundary.

Therefore the predictor envelope is a genuine component execution envelope, not an arbitrary interface cutoff.

## Scientific consequence

E3-D2 supports the manuscript distinction between:

```text
component candidate unavailable
```

and:

```text
outer coupled iteration failed
```

A coupler cannot accelerate or converge a response that the component cannot validly produce.

The result also argues against expanding coupling claims by simply increasing predictor forcing: before a strong-coupling conclusion can be drawn, the underlying SWAP predictor/corrector execution envelope must remain valid under the proposed state, forcing and window.

## Decision

**E3-D2 complete.**

No scientific tolerance was relaxed.

The original E3/E3-D boundary remains authoritative:

- `1e-4 day`: demonstrated predictor up to `3e-5 cm/day`;
- `1e-3 day`: demonstrated predictor up to `1e-4 cm/day`;
- `1e-2 day`: demonstrated predictor up to `1e-4 cm/day`.

Higher points require a separate component-qualification investigation rather than being treated as coupling-algorithm cases.
