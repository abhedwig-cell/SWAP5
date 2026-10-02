# PPA-WU05-C3A — production activation admission matrix

Date: 2026-10-01

Status: `ACTUAL_APPLICATION_QUALIFIED / FINAL_ADMISSION_PENDING`

The Bartholomeus production route is fail-closed.

| oxygen mode | oxygen type | water-film hydraulics | route |
|---|---:|---:|---|
| OFF | any | any | existing root-uptake route, oxygen disabled |
| 2 | 1 | analytical MvG | admitted Bartholomeus candidate |
| 2 | 1 | tabular / SWSOPHY=1 | unsupported pending separate qualification |
| other oxygen mode/type | any | any | unsupported by this slice |

The selector may not silently map unsupported historical oxygen configurations onto the new
Bartholomeus kernel.

The selected analytical route binds the reference water-film provider. Practical/WFT lookup remains
explicitly not admitted.

This activation decision owns only numerical/physics route selection. It does not own hydraulic,
thermal, crop, root-sink, or accepted-state storage.
