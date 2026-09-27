# F-PE-PHYS01 closeout — physical backend trial decomposition

Date: 2026-09-28

Status: `CLOSED_WITH_MATERIAL_SUCCESSORS`

## Decision

PHYS01 decomposed the backend time exposed by ORCH01 and found two material nontrivial successor families.

At N=40,000, worker=4:
- soil-water solver: about 55.5% of backend critical-path time;
- temporal-history certificate service: about 23.4%;
- backend residual outside `advance` including transaction/checkpoint/state cloning: about 15.0%;
- remaining in-`advance` setup/publication work: about 6.0%.

The shares are stable from N=1,000 through N=40,000.

## Primary successor

`F-PE-TEMPORAL09`:
decompose the temporal-history service into history handling, constitutive reevaluation, defect-operator assembly/tridiagonal solve and publication.

No temporal repair is selected before that measurement.

## Secondary successor

After TEMPORAL09, investigate the 13-15% backend residual as a separate transaction/checkpoint/state-cloning workunit if it remains material.

## Production boundary

Observation-only.
No production source change from PHYS01.

## Closure

`CLOSED_WITH_MATERIAL_SUCCESSORS`
