# F-ROMV2 D19 exact-contact merge adjudication

**Decision:** **FMC_EXACT_CONTACT_MERGE_RETAINS_RESEARCH_CANDIDACY**

## Question

D19 closes the transition left unresolved by D17 and D18.

D17 showed that FMC surface and groundwater branches remain competitive while their occupied intervals stay separated.

Canonical D18 then tested a natural D17-to-hiatus successor route, but no contact occurred inside its frozen 512-step event-search horizon. D18 therefore closed as an event-reachability no-go before SWAP exposure; it did not adjudicate merge hydrology.

D19 removes only that reachability ambiguity. It starts from an **exact-contact physical state**: in every active moisture bin a 5-cm falling slug terminates exactly where the groundwater-connected interval begins.

The primary-source merge rule then removes the slug representation and raises the same-bin groundwater front by exactly 5 cm. The occupied physical interval and finite-volume water are unchanged by the representation transition.

## Staged authority

### Stage 1 — FMC only

Run **35459320729**, job **105940197024**, artifact **10589417168**.

Artifact digest:

`sha256:7406d7faf80e451a9b24845fb053126c9da8df25ff46ff31d627cba350b5af6a`.

Decision:

`D19_FMC_EXACT_CONTACT_MERGE_PREFLIGHT_PASS`.

For X25, X50, X75 and X125:

- exactly 99 touching slugs merge at t=0;
- merge-storage residual is 0.0 cm at reported precision;
- maximum 64-step FMC ledger residual is 0.0 cm at reported precision;
- all post-merge groundwater-front states remain finite and physical.

No R16/R2 trajectory evidence was consumed in Stage 1.

### Stage 2 — matched SWAP comparison

Before Stage 2, canonical advanced only through ownership-disjunct HYDRO-MEMORY research evidence. The D19 scientific design was not changed.

Run **35459595130**, job **105940937202**, executed head

`4db9ddd59dd23d01e693b40d919c40c192d4eaf5`.

Artifact **10588638242**, digest

`sha256:37177c235c65e6e65041d2e7355fe22b29a7f014866f0e93846a9293b7a6d31a`.

Hydrological result SHA-256:

`15ed2980501673172204b3600801eaff6236dc42022e62d9ab479091fee3b004`.

R16 and R2 are each bitwise identical between O0 and O2.

## Full 64-step fidelity

| metric | FMC | R2 | FMC/R2 |
|---|---:|---:|---:|
| total-storage RMSE | 0.020838 cm | 0.029882 cm | 0.697 |
| cumulative bottom-exchange RMSE | 0.020838 cm | 0.029882 cm | 0.697 |
| mapped 10-cm theta RMSE | 0.0007051 | 0.045770 | 0.0154 |
| terminal bottom-flux RMSE | 5.019 cm d-1 | 7.100 cm d-1 | 0.707 |
| bottom-flux sign errors | 0/256 | 64/256 | — |

Every preregistered full-horizon gate passes.

The upper-zone FMC storage RMSE is about **0.000386 cm**. The lower-zone error remains larger, about **0.02104 cm**, and therefore still carries most of the balance discrepancy.

## Early post-merge fidelity

The first eight steps were separately preregistered because they are most sensitive to transition memory.

| metric | FMC | R2 | FMC/R2 |
|---|---:|---:|---:|
| total-storage RMSE | 0.002369 cm | 0.003545 cm | 0.668 |
| cumulative bottom-exchange RMSE | 0.002369 cm | 0.003545 cm | 0.668 |
| mapped 10-cm theta RMSE | 0.0001339 | 0.045808 | 0.00292 |
| terminal bottom-flux RMSE | 4.120 cm d-1 | 6.135 cm d-1 | 0.672 |
| bottom-flux sign errors | 0/32 | 8/32 | — |

Every preregistered early-transition gate also passes.

## Scientific meaning

D19 supplies the missing bounded evidence that the FMC falling-slug-to-groundwater **representation transition itself does not destroy the candidate's hydrological advantage over R2**.

This matters because the positive FMC evidence is now process-compositional rather than isolated:

1. D13: groundwater-front relaxation retained;
2. D16: surface infiltration/hiatus redistribution retained;
3. D17: simultaneous separated surface + groundwater operation retained;
4. D19: exact-contact merge plus post-merge groundwater relaxation retained.

D18 remains unchanged as a natural-route event-reachability no-go. D19 does not reclassify it.

## What D19 does not establish

D19 does not qualify:

- arbitrary rainfall sequences with repeated merge events;
- rainfall-runoff or ponding thresholds;
- moving groundwater-table coupling;
- ET or root uptake;
- drought and recovery;
- seasonal or multi-year balance;
- application acceptance;
- production runtime;
- production ROM.

The absolute bottom-flux RMSE remains material even though it is lower than R2.

## Next research decision

The most useful next step is no longer another microscopic front rule.

FMC has now survived the principal bounded hydraulic building blocks needed for a broader accelerator proposition. The next discriminator should test **persistence of that advantage over a longer, purpose-specific hydrological horizon**.

Two candidate directions are scientifically defensible:

1. longer hydraulic forcing with alternating surface input and groundwater response, still without ET, to test accumulation and repeated regime transitions;
2. rainfall/ponding/runoff threshold evidence, if fast-event surface behavior is the desired application class.

Formal runtime should remain deferred until at least one longer hydrological horizon is retained. A short transition benchmark is not sufficient for a practical speedup claim.

Production ROM remains unauthorized.
