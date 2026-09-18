# PUB-GC E6 preregistration — active-drainage hydrological stress coupling

## Status

**PREREGISTERED BEFORE E6 EXECUTION**

Date: 2026-09-18.

Canonical baseline:

`integration/f-ci-canonical@5d298c221caf4dbb917495f6e6a8718105df7208`

Publication line: PUB-GC / COUPLE.

## Purpose

E3 established a reproducible weak-feedback control: strong iteration closes the SWAP–groundwater interface residual, but the resulting groundwater-head correction remains extremely small before the simple F-GC44 component envelope becomes limiting.

E6 changes the **hydrological state/process configuration**, not the coupling tolerance, in order to ask:

> Does an already admitted wetter, active-drainage SWAP state produce a materially stronger vadose-zone–groundwater feedback when coupled through the same production participant and live MODFLOW6 prepared-solve lifecycle?

The active-drainage state is not invented for PUB-GC. It is taken from the independently qualified F-GC31 production tangent fixture.

## F-GC31 authority provenance

E6 reuses the already admitted restricted active-drainage tangent envelope:

- F-GC31 qualified source head: `fff0a8be74de3240d56a910f1b19eb4fb50146e9`;
- F-CI98 status: `integration/f-ci/F-CI98_STATUS.json`;
- F-CI98 admission gate workflow run: `35289371761`, conclusion success;
- independent F-VQ105 status head: `6451461a20c7e6dee6631f05f825705f62bf413b`;
- independent qualification accepted-substeps: 2;
- independent qualification retries: 3;
- O0/O2 output identity: true;
- no verifier production delta;
- fully implicit drainage remains explicitly NOT ADMITTED.

E6 does not alter those semantics.

## Hydrological source fixture

E6 reuses the F-GC31 admitted configuration:

- finite window: `0.01 day`;
- prescribed predictor lower-boundary flux: `2.0e-3 cm/day`;
- atmospheric/top flux: `0`;
- initial pressure heads: `[-2.2, -1.2, -0.2, 0.8] cm`;
- initial reported groundwater level carrier: `-0.3` in the FMR fixture;
- root extraction, macropores, snow and soil temperature inactive;
- drainage response active;
- smooth freatic projection active;
- two tabulated drainage levels:
  - level 1: groundwater depth `[0.5,2.5]`, signed exchange `[4e-3,1e-3]`;
  - level 2: groundwater depth `[0.5,2.5]`, signed exchange `[2e-3,-1e-3]`;
- F-GC31 tangent path independently qualified against production finite difference;
- drainage remains lagged per accepted substep, exactly as admitted by F-GC31. E6 does not promote it to a fully implicit within-substep drainage Jacobian.

## Coupling implementation

E6 must use:

- the production `fmr_groundwater_swap_participant_t`;
- the production `fmr_groundwater_head_forcing_materializer_t`;
- the production MODFLOW6 linear-response publication contract;
- live MODFLOW6 6.8.0 through the same prepared-solve session used by F-GC44.

The forcing materializer copies the full active-drainage base forcing and changes only the prescribed lower-boundary head for a corrector trial. No production coupling source is modified for E6.

## Groundwater model

Use the same controlled live-MODFLOW topology as E3:

- one layer, one row, three columns;
- centre cell coupled to SWAP;
- fixed heads on the end cells at +/-0.002 m around the predictor reference head;
- K = 1.0 m/day;
- SS = 0.02 1/m;
- specific yield scan:
  - 0.02;
  - 0.15;
  - 0.30.

This keeps the groundwater geometry comparable to E3 while changing the hydrological SWAP state/process configuration.

## Treatments

For every specific-yield value compare:

### L0 — loose constant exchange

Freeze the predictor groundwater-facing exchange and solve MODFLOW to its own convergence.

Afterwards execute one diagnostic SWAP prescribed-head trial from the immutable origin at the resulting groundwater head.

Record:

```text
r_L0 = q_SWAP(H_L0) - q_GW,L0
```

The diagnostic corrector is evidence overhead, not operational loose-coupling work.

### S — strong finite-window coupling

Use the same conjunctive coupling rule as F-GC44:

```text
MODFLOW nonlinear convergence
AND
|q_SWAP - q_GW| <= 1e-15 m/s
```

Each rejected SWAP corrector is discarded and the next one starts from the same captured accepted origin.

No tolerance or retry policy may be relaxed after observing a case.

## Primary outcomes

Per Sy value report:

- predictor reference head;
- predictor q_bot, q_u and u;
- predictor drainage activity/coverage provenance;
- loose head;
- loose groundwater-facing exchange;
- diagnostic loose SWAP exchange;
- loose interface residual;
- strong convergence status;
- strong outer iterations;
- strong accepted head and exchange;
- loose-to-strong head correction;
- loose-to-strong exchange correction;
- integrated whole-window exchange difference;
- component work;
- bounded SWAP or MODFLOW failure classification;
- mass accounting where available.

## Physical-materiality interpretation

E6 does **not** predeclare a universal threshold for hydrological significance.

Instead report absolute corrections alongside the E3 weak-feedback control.

A stronger-feedback result is supported if the active-drainage fixture produces a clear order-of-magnitude increase in head and/or whole-window transfer correction while remaining within the unchanged participant transaction envelope.

If the active-drainage case remains nanoscale, E6 records that as evidence that the current one-column/one-cell geometry is itself weakly coupled.

## Secondary E4-disambiguation observation

Where available, record the active-drainage non-bottom response contribution.

Because drainage is head/state dependent, E6 may produce:

```text
J_B != 0
```

and therefore help separate storage response from signed bottom-transfer response beyond the balance-aliased E4 control.

This is secondary. Failure to estimate a stable derivative does not invalidate the primary live-coupling experiment.

## Stop rules

- Production-participant parity with the direct F-GC31 physical fixture must pass before live-coupling interpretation.
- If the active-drainage predictor cannot produce an authoritative response, E6 stops as a component-envelope result.
- If the production forcing materializer drops or changes drainage controls, E6 stops; do not bypass it by modifying production semantics.
- A corrector-domain failure is reported as a participant-domain result, not outer-coupling divergence.


## Result adjudication rule

The active-drainage case is not called a positive strong-feedback result merely because drainage is active or because absolute exchange is larger than in E3.

Primary interpretation requires the **difference between loose and strongly converged coupling**:

```text
DeltaH_coupling = H_strong - H_loose

DeltaV_coupling =
    (q_SWAP,strong - q_SWAP,loose) * DeltaT
```

together with the loose interface mismatch, strong residual, outer-iteration count and transaction-authority checks.

A positive E6 hydrological-feedback result requires a clear order-of-magnitude increase in `|DeltaH_coupling|` and/or `|DeltaV_coupling|` relative to the E3/E3-R weak-feedback controls while all existing participant and convergence criteria remain unchanged.

If exchange magnitude increases but the loose-to-strong correction remains of the same nanoscale order as E3, E6 is classified as a **process-active but still weak-coupling result**.

This adjudication text is fixed before numerical E6 output is interpreted.


### Numerical E3-R comparison gate

To remove post-hoc ambiguity from "order-of-magnitude increase", E6 uses the largest already admitted E3-R loose-to-strong corrections as the conservative weak-feedback reference:

```text
max_E3R |DeltaH_coupling| =
    1.8311455685093847e-9 m

max_E3R |Deltaq_SWAP,coupling| =
    6.1084368016444556e-15 m/s
```

A preregistered **stronger-feedback positive** therefore requires at least one E6 case with:

```text
|DeltaH_coupling| >= 1.8311455685093847e-8 m

OR

|Deltaq_SWAP,coupling| >= 6.1084368016444556e-14 m/s
```

while the strong solve satisfies the unchanged `1e-15 m/s` interface criterion and the production participant remains within its admitted transaction domain.

The integrated whole-window transfer difference is still reported, but it is not used for the order-of-magnitude gate because E6 uses a 0.01-day window and the strongest converged E3-R case used a shorter window. The rate-based gate avoids classifying a case as stronger merely because the integration interval is longer.

This numerical gate is fixed before any E6 active-drainage workflow output is interpreted.
