# PUB-GC E7 result — realistic Hupsel component-domain limit

## Status

**CLOSED — REALISTIC_COMPONENT_DOMAIN_LIMIT**

Date: 2026-09-18.

E7 was executed according to the prospectively frozen Hupsel selection and stop rules. It closes at the production application-owner boundary **before** a loose or strong MODFLOW6 comparison is scientifically admissible.

## Frozen cases

The two dates were admitted in PR #325 before any coupled E7 output:

- median-dynamics control: **2003-06-17**;
- high-dynamics day: **2003-05-20**.

They were not replaced after observing the application-owner boundary.

## Exact Hupsel requirement

The exact authoritative Hupsel application has:

- `SWCROP=1`;
- `SWETR=0`;
- `SWDRA=1`;
- potato crop from 2003-05-10 through 2003-09-29 with `CROPTYPE=2`;
- the admitted PMdirect application mapping from emerged-crop potential transpiration into the root-uptake input.

Both frozen dates fall inside the potato period and both have positive standalone drainage:

| role | date | actual ET [cm d⁻¹ integrated over day] | drainage out [cm] |
| --- | --- | ---: | ---: |
| high dynamics | 2003-05-20 | 0.1146891077 | 0.9069694039 |
| median control | 2003-06-17 | 0.1791724035 | 0.0225868702 |

The whole-Hupsel typed adapter remains exact over 32,518 accepted intervals. E7 is therefore not stopped by missing Hupsel file parsing or by failure of the standalone typed application.

## Production groundwater-owner gate

The admitted config-to-owned-FMR groundwater route is PPA-WU01. It materializes the mode-5 prescribed-head groundwater participant only inside its deliberately restricted no-new-physics owner profile.

The owner explicitly rejects active:

- root extraction;
- drainage response.

A test-only extension of the existing production-owner qualification exercised both cases dynamically without changing production source.

PPA-WU01 workflow run **35375158471**, job **105698009081**:

```text
PPA_WU01_GROUNDWATER_ROOT_EXTRACTION_FAIL_CLOSED=PASS
PPA_WU01_GROUNDWATER_DRAINAGE_RESPONSE_FAIL_CLOSED=PASS
PPA_WU01_GROUNDWATER_ACTIVE_PROCESS_COMPOSITION_FAIL_CLOSED=PASS
PPA_WU01_O0_O2_OUTPUT_IDENTITY=PASS
PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS
```

The independent publication gate, run **35375158694**, job **105698010382**, also passed all frozen Hupsel/source/selection checks.

## Preregistered stop

The E7 preregistration explicitly allows:

`REALISTIC_COMPONENT_DOMAIN_LIMIT`

when an authoritative application interval cannot expose the required prescribed-head participant.

That condition is met before any F-GC49D context or MODFLOW6 timestep can represent the full selected Hupsel process composition.

Accordingly E7 did **not**:

- disable or freeze root uptake or drainage to create a coupling fixture;
- replace either selected date;
- merge or shorten event windows;
- calibrate the fallback groundwater model;
- relax solver, retry, mass or coupling tolerances;
- execute a synthetic loose/strong comparison and label it realistic.

No SWAP prescribed-head trial, MODFLOW timestep or interface-mass publication occurred after the failed process-complete application-owner admission. Committed hydrological authority therefore remained unchanged.

## Scientific interpretation

E7 answers RQ5 negatively but informatively.

The solver-autonomous coupling contract is interpretable under realistic application provenance, but the current production application envelope does not yet compose the authentic selected Hupsel crop/root and drainage processes with the prescribed-head groundwater owner.

This is **not outer-coupling divergence**. The numerical coupling algorithm is never reached with two valid process-complete participants.

The result extends the E3/E6 lesson from controlled stress cases to an independently selected realistic application: **component/application admissibility is itself part of the coupled-model domain**.

E7 therefore closes as a realistic component-domain result rather than as a successful regional Hupsel–MODFLOW validation.

## Future boundary

A future, independently admitted production groundwater owner that composes the required active processes could support a new realistic loose-versus-strong experiment. That would be new evidence. It does not retroactively change the preregistered E7 outcome.
