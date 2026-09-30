# PPA-WU05-A6 R5 source map — standard-route inflow limitation and top excess redistribution

Date: 2026-09-30

Status: EXACT_SOURCE_MAP / TYPED_IMPLEMENTATION_IN_PROGRESS

## Scope

This R5 slice migrates the B1.11 standard-domain inflow limiter used for swmbf=1 and for id>1 under swmbf=2.

The main kinematic-wave domain keeps its separate source path and is not silently mapped onto this limiter.

## Per-domain limiter

Potential total inflow:

FlwInDmTot = TopVertical + TopLateral + InInterflowSat + InMatrixSat.

Potential total outflow:

FlwOutDmTot = OutMatrixSat + OutMatrixUns plus rapid drainage for domain 1.

Temporary storage:

WaTmp = WaAccepted + FlwInDmTot - FlwOutDmTot.

Maximum admissible storage is normally total active domain volume.

When essentially all inflow is real-groundwater saturated-matrix inflow, the source restricts maximum storage to the volume below matrix groundwater level.

If WaTmp exceeds WaMax and total inflow is positive:

FrFlwIn = max(0, 1 - (WaTmp-WaMax)/FlwInDmTot).

The same FrFlwIn multiplies all incoming terms.

Only the rejected share of TopVertical+TopLateral is accumulated as top excess.

## Cross-domain redistribution

After every domain is evaluated, accumulated top excess may be redistributed to domains with remaining saturation deficit.

Domains are ordered by ascending relative saturation deficit.

The transferable share uses PpDmCp at the top macropore compartment relative to the remaining PpTot.

Only accepted top vertical/lateral terms are increased during redistribution; saturated matrix/interflow terms are not.

Remaining top excess is returned to the surface/lateral owner.

## Typed contract

The typed generator returns:

- per-domain FrFlwIn;
- accepted top vertical/lateral amounts;
- accepted interflow/main-saturated amounts;
- total rejected top amount;
- redistributed top amount per domain;
- final returned-surface amount;
- receipt residual.

All quantities are amounts over the current physical step, matching B1.11 limiter semantics.