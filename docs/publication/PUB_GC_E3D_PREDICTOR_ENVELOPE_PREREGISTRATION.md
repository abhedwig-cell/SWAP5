# PUB-GC E3-D preregistration — predictor-envelope diagnosis

## Status

**PREREGISTERED AFTER E3 MAIN RESULT, BEFORE E3-D EXECUTION**

Date: 2026-09-18.

E3 main matrix result:

- 48 prespecified cases executed;
- 12 low-flux cases converged;
- 36 cases with `q_predictor >= 1e-3 cm/day` returned `SWAP_PREDICTOR_UNAVAILABLE`;
- failure occurred before MODFLOW feedback.

E3-D is a diagnostic follow-up. It is not retroactively part of the original E3 hypothesis matrix.

## Objective

Locate the real-SWAP predictor envelope between the admitted F-GC44 control and the first failed E3 flux level, and identify the exact qualification stage that rejects the predictor.

No production tolerance, physics or admission criterion may be relaxed.

## Predictor-only scan

For each coupling window:

```text
DeltaT_day =
    1e-4
    1e-3
    1e-2
```

scan:

```text
q_predictor_cm_per_day =
    1e-6
    3e-6
    1e-5
    3e-5
    1e-4
    3e-4
    1e-3
```

Total:

```text
21 predictor cases
```

MODFLOW conductivity is deliberately absent because the observed E3 failure occurs before any live groundwater solve.

## Stage codes

The qualification-only bridge shall expose distinct non-zero initialization statuses:

```text
101 invalid configured input
102 committed-state initialization failure
103 checkpoint capture failure
104 predictor whole-window trial incomplete
105 predictor candidate unavailable
106 accepted-trajectory direction unavailable
107 tangent endpoint prerequisites/materialization invalid, or tangent endpoint invalid/not authoritative
108 origin bottom-face mapping invalid
109 SWAP interface-flux conversion failed
110 groundwater action/reaction pairing failed
111 predictor-origin capture failed
112 predictor-response assembly failed
113 tile/cell affine response composition failed
114 MODFLOW linear boundary-term composition failed
115 SWAP participant origin capture failed
116 interface-ledger identity bind failed
0   predictor ready
```

These codes are diagnostic only; the default F-GC44 pass/fail contract remains zero versus non-zero.

## Recorded values

For successful predictor cases:

- configured window;
- configured predictor flux;
- response `u`;
- predictor `q_u`;
- predictor start/end head;
- canonical storage start/end/change;
- canonical mass residual.

For rejected cases:

- exact stage code.

## Interpretation

### Transaction/trial failure (104–106)

The blocker belongs to the real SWAP predictor execution or accepted-trajectory directional publication.

### Tangent/interface construction failure (107–114)

The SWAP physical trial exists, but the response representation or interface mapping is outside its admitted numerical envelope.

### Participant/ledger setup failure (115–116)

The predictor itself is valid and the blocker is composition infrastructure.

## Stop rule

E3-D does not extend the flux scan beyond `1e-3 cm/day` in this workunit.

If all levels above `1e-6` fail at the same stage, the next workunit must diagnose that stage directly rather than increasing forcing further.

If a transition is found, the largest successful and smallest failed levels define the bounded interval for a later hydrological coupling case.

No success threshold is moved after observing the scan.


## Diagnostic implementation note

The stage code is returned only by the qualification-only configurable F-GC44 initializer used by this publication harness. The ordinary zero/non-zero F-GC44 interface remains compatible, and no production SWAP5 or MODFLOW6 API is changed.

The scan values, stop rule and interpretation rules above were fixed before this diagnostic workflow was executed.
