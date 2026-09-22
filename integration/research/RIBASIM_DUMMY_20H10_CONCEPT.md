# RIBASIM-DUMMY-20H10

## Question

What happens when fixed `allocation.dt` is not commensurate with the actual
RibaMod/MF6 BMI step cadence?

The bundled Ribasim v2026.1.1 BMI route is start-time gated:

```text
BMI.update_until(t_next)
  -> step!(dt = t_next - t)
  -> if current t is an allocation multiple:
       update_allocation!
  -> advance the whole requested dt
```

The callback set contains no separate fixed-allocation callback. RibaMod in turn
calls `update_until` only after each MF6 product step.

## Frozen falsification

With 6 h MF6 steps:

```text
A6: allocation.dt = 6 h
step starts = 0, 6, 12, 18 h
allocation records expected = 0, 6, 12, 18 h
```

With 5 h allocation cadence:

```text
A5: nominal allocation boundaries = 0, 5, 10, 15, 20 h
step starts = 0, 6, 12, 18 h
intersection through day 1 = 0 h only
allocation records expected = 0 h only
```

If qualified, this means the effective management cadence in the product
composition is not determined by `allocation.dt` alone when clocks are
noncommensurate. It is constrained by exact coincidence with BMI call-start
times.

This is a runtime-contract finding, not yet an upstream defect classification.
