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

## Falsification of lifetime hypothesis

Direct provider sweep falsified the initial lifetime interpretation. The provider remains available across ordinary states. The observed unavailable route is `active-runoff-outside-profile`: with positive candidate ponding, very small retry dt, ponding_max=0 and runoff_resistance=0, the dynamic-top evaluator enters runoff but deliberately rejects that runoff configuration as outside its qualified linear profile.

Therefore provider lifetime is not established as causal. Model-owned provider experiments are not part of the justified repair and must not be promoted on this evidence. Q4B fixture configuration is corrected to a supported positive ponding threshold and linear runoff resistance instead.

## Falsification

The lifetime hypothesis is rejected. A direct dynamic-top provider sweep shows the provider remains AVAILABLE across the relevant pressure-head range until an active-runoff case combines ponding with a retry-scale dt and `runoff_resistance_day=0`. That case returns `active-runoff-outside-profile`, as designed: the qualified analytical runoff route requires linear runoff with resistance >= 0.001 day.

Q4B had configured `ponding_max=0`, `runoff_exponent=1`, and `runoff_resistance_day=0`. Once ponding developed, retry substeps therefore entered an explicitly unsupported top-boundary profile. This is a fixture configuration error, not provider lifetime loss.

The model-owned provider changes are not justified by this evidence and must not be promoted as the repair. Q4B is corrected to use a positive linear runoff resistance within the already supported profile.
