# F-RFM-TOPLIFE-01 — dynamic top-provider lifetime

Date: 2026-10-03
Status: REPAIR_CANDIDATE_UNDER_QUALIFICATION

## Discovery

After F-TEMP-MODE3-01 removed the mode-3 temporal blocker, long Q4B exact-RFM execution reached a later HeadCalc state and stopped with:

`HeadCalc: dynamic top-boundary provider unavailable`

The request correctly selected FSI_TOP_MODE_DYNAMIC_PROVIDER for active RFM.

## Root cause candidate

The RFM dynamic top provider was a TARGET local variable of `fmr_serialized_advance`. A polymorphic pointer in the solve request was associated with that local provider. The provider itself owns pointer components to geometry/hydraulic parameters. Long/retried legacy execution exposed an unavailable provider state.

The provider is runtime model context, not physical committed state. Give it model-owned lifetime, matching the backend/model ownership of the parameter objects it references. Rebind its values for every advance before placing its address in the request.

## Repair boundary

Only provider lifetime changes. No RFM physics, panel policy, top-boundary equations, mass accounting or solver tolerances change.
