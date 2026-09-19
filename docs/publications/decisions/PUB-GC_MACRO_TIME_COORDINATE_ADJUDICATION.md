# PUB-GC macro-window temporal-coordinate adjudication

Status: **frozen after PUB-GC-NATIVE-TIME-0001 and before corrective implementation**

Publication owner: `PUB-GC`

## 1. Triggering evidence

`PUB-GC-NATIVE-TIME-0001` was preregistered before implementation and executed unchanged.

Controlling receipt:

`docs/publications/results/PUB-GC-NATIVE-TIME-0001.yaml`

Outcome:

`NO_POLICY_SELECTED`

All five cases executed at N0 (4 x 0.01 d) and N1 (8 x 0.005 d), while N2 (16 x 0.0025 d) and N3 (32 x 0.00125 d) returned `PUB_GC_MACRO_INVALID`.

This result is preserved and will not be overwritten.

## 2. Root cause

The qualified research macro component currently constructs absolute native boundaries as:

```text
t1 = t0 + delta_t_i
t0 = t1
```

and after the last contribution requires:

```text
abs(t0 - macro_t1) <= 1e-12 day
```

For macro origin 4200.125 d and duration 0.04 d, repeated binary64 addition yields approximately:

- 4 x 0.01 d: +9.09e-13 d closure error;
- 8 x 0.005 d: +9.09e-13 d;
- 16 x 0.0025 d: -6.37e-12 d;
- 32 x 0.00125 d: +8.19e-12 d.

The invalidity therefore depends on the number of floating-point additions at a large absolute time coordinate, not on Richards convergence or physical state.

## 3. Rejected correction

Do **not** merely increase `macro_time_tolerance_day`.

That would allow the accumulated absolute-time drift to pass but would leave the component's native boundaries dependent on repeated addition of small durations to a large absolute coordinate.

The publication method requires a clearer temporal contract.

## 4. Admitted correction

Inside one macro-window, native scheduling is represented first in **relative elapsed time**.

Let:

```text
e_0 = 0
e_i = compensated_sum(delta_t_1 ... delta_t_i)
```

For contribution `i`:

```text
t_start_i = macro_t0 + e_(i-1)
```

For all nonfinal contributions:

```text
t_end_i = macro_t0 + e_i
```

For the final contribution:

```text
t_end_m = macro_t1
```

Thus the authoritative external macro boundary remains exact while internal boundaries are constructed from relative offsets rather than chained absolute additions.

Use compensated summation for the relative elapsed coordinate.

## 5. Duration validation

The nominal native-duration sum must still match the macro duration before execution.

Use the compensated relative sum and the existing duration tolerance:

```text
abs(e_m - (macro_t1-macro_t0)) <= 1e-12 day
```

This is a comparison between quantities of macro-duration scale and is therefore not relaxed by absolute calendar magnitude.

No post-result tolerance change is permitted.

## 6. Actual represented interval telemetry

Binary64 absolute boundaries imply that the represented transaction duration:

```text
delta_t_actual_i = t_end_i - t_start_i
```

can differ from the nominal `delta_t_i` by sub-ULP amounts at the absolute time scale.

The revised research response must expose:

- nominal `native_dt_day(i)`;
- actual `actual_native_dt_day(i)`;
- maximum absolute nominal/actual duration difference.

This is provenance telemetry, not an H2/H3 metric.

Each actual interval must remain positive and finite.

## 7. External macro endpoint

After the final internal commit:

- the disposable committed time must be exactly the supplied `macro_t1` at binary64 representation;
- the response is invalid otherwise.

This is preferable to accepting an accumulated near-miss at the external coupling boundary.

## 8. Qualification extension

Create new qualification ID:

`PUB-GC-MACRO-WINDOW-QUAL-0002`

It must rerun every previously frozen macro qualification oracle Q0-Q7 without weakening any criterion and add:

### Q8A — 16-contribution closure
- macro origin: 4200.125 d;
- macro duration: 0.04 d;
- 16 x 0.0025 d;
- constant qualification-only forcing and prescribed -80 cm bottom head;
- complete response;
- final disposable time exactly `macro_t1`;
- all actual native durations positive/finite;
- compensated nominal duration closes the macro duration;
- source state remains authoritative and unchanged.

### Q8B — 32-contribution closure
Same requirements with 32 x 0.00125 d.

### Q8C — absolute-time translation control
Repeat the 32-contribution timing fixture from an absolute origin shifted by +10000 d, using the same physical initial state and relative forcing schedule.

The purpose is timing arithmetic only. No hydrologic equality across absolute-time origins is required unless the underlying qualified physics is itself absolute-time invariant; required assertions are successful temporal closure, positive/finite represented intervals and authoritative-origin isolation.

## 9. Research scope

Allowed changes remain research-only:
- macro-window publication test component;
- macro qualification tests/runners/workflow.

Forbidden:
- `src/**`;
- production time contracts;
- production coupling policy;
- solver physics;
- H2/H3 thresholds or primary cases.

## 10. Native-time continuation

Only after `PUB-GC-MACRO-WINDOW-QUAL-0002` passes may a new study ID be frozen:

`PUB-GC-NATIVE-TIME-0002`.

To prevent post-hoc tuning, NATIVE-TIME-0002 must reuse **unchanged**:
- N0/N1/N2/N3 ladder;
- all five NATIVE-TIME-0001 cases;
- all four adequacy thresholds;
- coarsest-passing selection rule.

The only changed dependency may be the newly requalified macro temporal-coordinate component.

## 11. Interpretation

This adjudication addresses research infrastructure representation.

It creates no evidence for:
- H2;
- H3;
- practical coupling-window limits;
- MODFLOW6 transfer;
- PUB-RC acceleration;
- PUB-SQ solver performance.
