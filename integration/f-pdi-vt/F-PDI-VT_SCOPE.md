# F-PDI-VT: PDI vapor-conductivity temperature audit

## Role

Independent hydraulics audit/fix workstream for the PDI vapor-conductivity temperature formulation.

This workstream is intentionally separate from F-AHL. F-AHL remains closed. No acceleration architecture is changed here unless and until the upstream PDI vapor physics is independently reconciled.

## Triggering evidence

F-AHL26D0 established that the current PDI vapor function receives soil temperature in degrees Celsius and is called over a runtime domain that may include negative temperatures, while the present source expression for saturated vapor density behaves pathologically:

- at -5 deg C the evaluated expression overflows;
- at 5 deg C the tested expression underflows to zero;
- at 20 and 35 deg C it returns extremely small values.

This is not yet classified as a confirmed physics/code bug. It is an audit finding requiring theory-documentation-code reconciliation.

## Authority order

Use:

1. current canonical SWAP5 and frozen corrected SWAP4.3.1/B1 sources;
2. exact PDI source implementation and SWAP-009 Kelvin-sign evidence;
3. official SWAP documentation/manual equations and parameter/unit definitions;
4. primary scientific literature for PDI and vapor conductivity;
5. independent dimensional/numerical checks.

Do not infer a correction from common formulas without binding source/documentation authority.

## Workflow

RECONCILE -> SOURCE TRACE -> DOCUMENTATION TRACE -> THEORY TRACE -> CLASSIFY -> PREREGISTER FIX if uniquely determined -> IMPLEMENT -> QUALIFY -> PERSIST -> CLOSE

## Central questions

1. What temperature variable and unit is intended in Kvap_func?
2. What is the intended saturated vapor-density equation, including its temperature scale and constants?
3. Is the current expression a transcription/unit bug, a documentation mismatch, or something else?
4. What range of soil temperatures is scientifically and operationally intended for PDI vapor conductivity?
5. If a defect is confirmed, what is the minimal source-authoritative correction?
6. Does the correction preserve the already-admitted SWAP-009 signed-head Kelvin fix?
7. What changes in function-level and representative full-SWAP PDI behaviour result?
8. Does mass balance and nonlinear convergence remain acceptable?

## Hard constraints

- No F-AHL gate changes.
- No invented vapor formula.
- No silent Celsius/Kelvin reinterpretation.
- No production admission before independent qualification.
- Preserve negative findings and all source identities.
