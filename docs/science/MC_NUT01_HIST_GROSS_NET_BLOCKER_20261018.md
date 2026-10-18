# Historical gross atmospheric carrier: executable completion blocker

Status: diagnostic counterexample, not a new admitted physical contract.
Base canonical: `1e8bf36ec52544e50f5b2720031228f9a6369525`.

## What is demonstrated

The current bounded atmospheric contract accepts one signed surface-water rate.
The mineral owner uses its positive part for dissolved atmospheric N input and
its signed value for the hard water balance. The historical management source
instead forms `Wflux_inTop` from precipitation, snow, irrigation, interception,
runon and runoff (lines400..402), with evaporation separate (line401).
The original comment explicitly questions the meaning under ponding.

The executable witness calls the unchanged original `Wofost_SoilWaterN` and the
actual current four-provider mineral owner. It does not translate the original
transport into a second production implementation. Both source files are checked
against their existing SHA-256 authority pins before compilation.

For a30cm column at water content0.3, with no lower or lateral exchange or root
uptake, three days have the same net surface flux0 and the same water endpoint:

| Rain | Soil evaporation | Original NH4 input | Original NO3 input | Current net-carrier input |
| --- | --- | --- | --- | --- |
| 0mm | 0mm | 0 | 0 | 0 |
| 4mm | 4mm | 0.000020kg/m2 | 0.000060kg/m2 | 0 |
| 8mm | 8mm | 0.000040kg/m2 | 0.000120kg/m2 | 0 |

Concentrations are0.005 and0.015kg N/m3. These are controlled diagnostic cases,
not measured field weather. The original transport preserves the independently
computed gross N input. The current owner correctly conserves its admitted net
input, but that input cannot distinguish the three historical cases.
Substituting gross rain for the net carrier fails the unchanged water budget;
the witness confirms no clock, water or mineral-inventory publication.
This is an information deficit, not evidence of a defect in the bounded contract.

## Alternatives assessed

1. Continue using net infiltration: preserves current conservation but loses the
   historical gross N input in the demonstrated cases. Cannot qualify full HIST.
2. Pass gross rain as signed surface water: violates the water balance; rejected.
3. Manufacture drainage to close that balance: introduces unobserved water and
   N export; violates Richards ownership and is excluded.
4. Inject a separate N transfer: could preserve total N, but does not by itself
   reproduce original within-day concentration, uptake, sorption and reaction
   timing. No such shortcut was added.
5. Use the surface-age store: it carries water age, not dissolved-N inventories.
   Its existence is not qualification of a surface solute store or its restart.

A complete migration needs an explicit reference decision: reproduce historical
gross atmospheric loading, or qualify a corrected B1 surface-solute balance with
ponding/runoff/infiltration and retained N. The latter requires coupling accepted
surface water and dissolved N through existing owners, including rejected trials
and native restart. This witness does not choose pond storage, mixing, runoff
concentration or precipitation/evaporation ordering without evidence.

This blocks the requested *full* historical hydrological equivalence. It does
not invalidate the qualified730-day fixed-flux rotation, atmospheric or humus
scenarios. Noncontiguous material labels, general TTUTIL constructs, fractional
timestamps and extended diagnostics also remain open. Mastercoverage is unchanged.

## Reproduction and evidence

Run the additive forensic driver, outside the production admission/test closure:

```bash
N_CARRIER_GAP_RESULT_DIR=/absolute/new/output python integration/audits/run_nut_hist_carrier_gap.py
```

`gfortran` must be on PATH. It builds the four current production providers and
the pinned original transport at O0/O2, with bounds/FPE checks, retaining compiler,
link and native commands and complete stdout/stderr. A diagnostic PASS proves the
counterexample and rejection checks only. It cannot authorize full migration.
The versioned evidence capsule and exact execution commit are recorded in the
existing work-unit status. No solver, chemistry, parser, restart or existing
qualification input is changed by this audit.
