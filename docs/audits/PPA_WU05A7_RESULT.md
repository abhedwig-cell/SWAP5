# PPA-WU05-A7 result — production-shaped single-column admission candidate

Date: 2026-09-30

Status: QUALIFIED_PRODUCTION_SHAPED_SINGLE_COLUMN_ADMISSION_CANDIDATE

Qualified head: ce978df3314f9b921490a18233ef0637e64f341c

Qualification evidence:
- promotion/runtime contract run 36778367034: SUCCESS;
- real Reference Richards run 36778367043: SUCCESS.

## Production-shaped implementation

The qualified A5/A6 Fortran components now live under production-owned src/process/macropore and src/runtime paths.

A production-shaped single-column runtime wraps the existing Reference Richards solver through a source/sink overlay. It never sets the inner Richards request macropore_active flag, so the existing HeadCalc reference path remains unchanged.

## Disabled preservation

With runtime policy disabled:
- the ordinary source/sink provider remains authoritative;
- matrix candidate water state is bitwise identical to direct solver execution;
- accepted macropore continuation state is copied unchanged.

## Active strict route

The runtime performs predictor -> source-rate bundle -> damped outer correctors -> candidate composition -> sorptivity-history update -> corrected vertical flux reconstruction.

It returns retry outward and never mutates committed macropore state.

## Real Richards evidence

On the bounded sorptivity-only production case:
- outer iterations: 20;
- QExc: 0.06285842510262735 cm/d;
- solver matrix mass residual: 2.974009927e-17 cm;
- macropore balance residual: 6.411700598e-17 cm;
- O0/O2 outputs identical.

Markers:
- PPA_WU05A7_PROMOTION_GATE=PASS;
- PPA_WU05A7_DYNAMIC_CRACK=PASS;
- PPA_WU05A7_SINGLE_COLUMN_RUNTIME=PASS;
- PPA_WU05A7_REAL_RICHARDS_RUNTIME=PASS;
- PPA_WU05A7_REAL_RICHARDS_GATE=PASS.

## Trial-duration ownership

The runtime now binds the actual physical trial duration into all unsaturated, saturated, rapid-drain and history-update calculations. It does not reuse a preregistered/template dt.

## Dynamic crack

A production-owned dynamic crack evaluator reproduces the A3/A4 history oracle.

Dynamic crack geometry is not yet coupled inside the first production admission candidate corrector loop. Geometry remains fixed over a trial; this avoids introducing geometry-displacement water without a corresponding matrix corrector source.

## Remaining blocker for FMR admission

The production runtime currently receives a prepared macropore geometry/rate/history configuration.

FMR still rejects parameters%macropore_active and does not yet own a production adapter that derives, for each accepted/trial state:
- top water-storage compartment and wet fraction;
- macropore water/reference level and saturated interface view;
- main matrix saturated-zone indices/fractions;
- optional perched saturated-zone view;
- source top-input partition request from surface forcing;
- rapid-drain derived view;
- immutable macropore physical configuration carrier.

Therefore the runtime is an admission candidate component, not a canonically admitted FMR capability.

## Decision

QUALIFIED_PRODUCTION_SHAPED_SINGLE_COLUMN_ADMISSION_CANDIDATE_FMR_ADAPTER_PENDING.