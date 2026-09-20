# F-ROM-LARE C4U groundwater application-acceptance authority boundary

**Status:** BLOCKED_EXTERNAL_PROJECT_ACCURACY_EVIDENCE_REQUIRED  
**Decision:** `GW_APPLICATION_ACCEPTANCE_NOT_ADJUDICABLE_FROM_CURRENT_REPOSITORY_AUTHORITY`

## Why C4U exists

C4T established a bounded shared-host cost-fidelity value signal after blind C4R validation and full C4S common-cohort qualification. That is still not enough to choose a LARE resolution for a real groundwater application.

The canonical coupling architecture already contains the correct place for application-owned accuracy policy:

- `coupling_application_accuracy_contract_t` carries an externally qualified groundwater-head or drawdown requirement `H_app`;
- an independently qualified temporal allocation `A_temporal` or direct temporal budget allocates part of that application requirement to temporal/model error;
- `mod_groundwater_accuracy_binding` binds governed head-domain budget to the coupling policy;
- F-GC29 can expose a provenance-bound local `dh_groundwater/dq_groundwater` response for an exact accepted trial/window.

What is missing is not a model equation. It is the real application policy.

## Existing governance is deliberately fail closed

F-GC13 and F-GC14 explicitly state that no real project `H_app`, `A_temporal`, or direct temporal head-error budget has been qualified. Their synthetic values are qualification fixtures only.

This forbids several tempting substitutions:

- do not use C4R/C4T observed errors as the acceptance threshold;
- do not use the Reference numerical floor;
- do not use Richards convergence tolerances;
- do not use coupling iteration tolerance;
- do not reinterpret calibration or observation-fit criteria as an application prediction-error requirement;
- do not use the F-GC10/F-GC13 synthetic 8, 10 or 12 cm examples or their allocation fractions.

## Required external authority

A real project must provide an externally governed packet containing at least:

1. the groundwater QOI, head and/or drawdown;
2. an explicit numerical application prediction-error requirement `H_app`;
3. the application scope, spatial support, prediction horizon and decision/use case;
4. an independently governed temporal allocation `A_temporal`, or a direct temporal head-error budget not exceeding `H_app`;
5. immutable provenance identifiers and source-byte digests verified outside the SWAP kernel.

Only then can the C4R/C4T groundwater error vector be turned into an application acceptance decision.

## How the existing sensitivity seam can be used

For GW-D, the admitted F-GC29 response can be used locally when it is available and smooth:

`delta_h approximately (dh_groundwater/dq_groundwater) * delta_q`.

That relation is valid only for the exact provenance-matching local trial/window. It is not a seasonal transfer function. Unavailable or nonsmooth response must fail closed or be replaced by an actual coupled counterfactual.

For GW-R, the correct route is to aggregate exchange on the real coupling interval and propagate the ROM-versus-reference exchange perturbation through the admitted downstream groundwater model over the declared application horizon. Systematic signed exchange bias remains a separate diagnostic.

## Current consequence

The current repository can say that LARE R3-R8 occupy a resolved relative cost-fidelity frontier on the tested fixed-water-table B01 workload. It cannot say which member is acceptable for an actual groundwater application.

The workstream therefore stops at an external-source boundary. No new LARE closure, coupling architecture, performance screen or production ROM is authorized while the project accuracy packet is absent.
