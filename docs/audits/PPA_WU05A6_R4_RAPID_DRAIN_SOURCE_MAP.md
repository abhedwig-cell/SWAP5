# PPA-WU05-A6 R4 source map — multi-compartment rapid drainage

Date: 2026-09-30

Status: EXACT_SOURCE_MAP / TYPED_IMPLEMENTATION_IN_PROGRESS

Authority: B1.11 RAPIDDRAIN.

Rapid drainage exists only in main bypass-flow domain 1.

Activation depends on drain type and main-domain bottom relative to the rapid-drain level.

Compartment conductance weight:

KDCrRlCp = ((WthCr^RapDraReaExp)/DiPo) * Dz,

with top active compartment multiplied by SatFr.

Total KDCrRl is the sum over active compartments.

Drainable water is WaSrMpDm minus macropore volume below drain level.

Hydraulic head difference is max(0, ZWaLev-max(ZDraBas,ZBtDm)), plus ponding when ZWaLev is at the surface.

Resistance scales by min(KDCrRlRef/KDCrRl,1.1).

Total rapid drainage is capped by drainable storage and distributed back to compartments by KDCrRlCp/KDCrRl.

The total is one external accepted outflow.