# RM13 technical setup disposition: Ribasim solver.saveat

## Trigger

The first release-loader smoke reached exact Ribasim v2026.1.1 successfully after binding the bundled Julia runtime, but model initialization failed before any physical or allocation solve with:

`A finite saveat must be an integer number of seconds. saveat = 8.64`

This is exact-release configuration validation, not a coupled-model result.

## Classification

**TECHNICAL_SETUP_FAILURE**

The frozen RM13 physical window remains 8.64 s and the frozen allocation cadence remains `allocation.dt = 8.64 s`.

The failing field is only `solver.saveat`, which RM01 already excludes as an allocation-cadence owner. It controls result saving, not the management solve clock.

## Repair

Use:

`solver.saveat = Inf`

for RM13.

In Ribasim v2026.1.1, `Inf` is explicitly converted to start/end-only saving. This avoids introducing any new finite output cadence and leaves:

- model start/end time unchanged;
- `allocation.dt = 8.64 s` unchanged;
- UserDemand request unchanged;
- physical source supply unchanged;
- all RM13 water quantities unchanged;
- all SWAP and MODFLOW settings unchanged;
- all preregistered scientific tolerances unchanged.

The original preregistration remains preserved. This file records why the technically invalid output setting is replaced rather than silently edited into a passing case.

## Nonclaim

This disposition does not qualify any new clock semantics. RM11/RM12 remain the allocation-clock authority.
