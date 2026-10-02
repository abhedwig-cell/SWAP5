# F-MIG431-LOW03-A shared prerequisite: serialized legacy-context mode-3 reachability

Status: OPEN CENTRAL PREREQUISITE. This record is evidence from LOW03-A qualification and is not authorization to mutate shared context authority.

## Trigger

LOW03-A branch qualification run 36987639976 at postimage `67ec5945888077b6fa6c36f8e803c060249458c0` fails before the soil-water solver is invoked.

Observed evidence:

- frozen corrected-B1.11 source-law oracles: PASS;
- standalone typed Cauchy provider: PASS;
- production profile: ADMITTED;
- proposal carrier: available with t0=5100.1875, original t1=5100.6875;
- resolved Haq: -75 cm total head;
- resolved Q4: 0 cm/day;
- transaction: three solver rejections after two retries;
- final serialized observation: `solver_executed = false`, `solver_status = 0`, route `not-run`.

The failure is deterministic and precedes `self%solver%solve`.

## Root cause

`src/adapter/mod_b110_serialized_context_binding.f90` owns the shared bridge from an explicit typed Reference request into the legacy call context. Its admission guard currently allows only bottom modes 7, -2, 5 and 2:

```fortran
if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
    request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2) return
```

LOW03-A correctly materializes typed mode 3 only after the application proposal/Q4 clocks have been resolved. The shared context bridge then rejects that request and returns `context_ok=.false.`; `fmr_serialized_advance` returns before the solver call.

This is not a LOW03-P0 solver failure. The admitted typed solver already accepts mode 3 and owns its residual/Jacobian through `soil_water_boundary_conditions_t`.

## Minimal prerequisite delta

Central authority must explicitly qualify the semantic successor of `mod_b110_serialized_context_binding` that permits typed `bottom_mode=3` on the already bounded Reference route.

The minimal candidate change is only the mode allowlist:

```fortran
request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2 .and. &
request%boundary%bottom_mode /= 3
```

No new legacy global for RIMLAY, Haq or Q4 is required or authorized. The typed boundary object already carries:

- `bottom_head`: external total Haq;
- `bottom_flux`: trial-local Q4;
- `bottom_external_resistance_days`: RIMLAY;
- `bottom_include_half_cell`: vertical-resistance switch.

The context bridge may continue mirroring only `swbotb`, qtop/qbot/hbot and the existing numerical globals. HeadCalc receives the typed boundary object directly and LOW03-P0 owns the mode-3 resistance law.

## Required central qualification

Before LOW03-A may consume this successor, central qualification must show:

1. existing modes 7, -2, 5 and 2 are bit/marker preserved;
2. typed mode 3 reaches the Reference solver only when its typed request has already passed LOW03-P0 domain validation;
3. RossFast cannot acquire mode 3 through this bridge;
4. macropore and SWKIMPL1 remain rejected by their existing owners;
5. no legacy-global resistance/head/Q4 ownership is introduced;
6. LOW03-P0 direct solver qualification remains unchanged;
7. existing LOW05-A, LOW01-A and prescribed-qbot application qualifications remain green;
8. any historical hash guard that covers this shared adapter is adjudicated against current canonical rather than silently allowlisted.

## Scope boundary

This prerequisite does not admit LOW03-A by itself. It only restores serialized reachability from the already typed application request to the already admitted typed mode-3 solver. LOW03-A must still prove proposal-versus-trial timing, transaction/restart behavior, mass closure, A/B/A isolation and preservation after the prerequisite is centrally accepted.

No sibling or repair branch is created by this record.
