# PUB-GC / COUPLE figure and table plan

## Purpose

Keep the manuscript evidence-driven. Each figure must support a specific claim in the claim–evidence ledger and must distinguish numerical coupling quality from hydrological effect.

No figure may imply a broader qualified envelope than the underlying experiment.

## Figure 1 — coupling ownership and finite-window lifecycle

**Claim support:** GC-C01, GC-C02, GC-C03.

Show:

- coarse model/orchestration layer;
- internal SWAP5–MODFLOW6 coupling service;
- SWAP accepted checkpoint;
- predictor and repeated correctors from the same origin;
- one MODFLOW prepared nonlinear solve;
- separate component convergence and coupled-interface convergence;
- publication boundary.

Key visual distinction:

~~~text
calculation
    !=
accepted model state
    !=
published interface mass
~~~

Do not depict the coupler as owning the Richards or MODFLOW internal solver.

## Figure 2 — hydrological interface quantities

**Claim support:** GC-C05 and later GC-C09.

Show the fixed lower SWAP coupling plane and distinguish:

- hydraulic head H at the plane;
- native SWAP q_bot;
- groundwater-facing q_u / q_swap convention;
- storage change inside the SWAP column;
- whole-window V_out;
- datum/elevation relation.

This figure should make it visually impossible to read q_bot and q_u as aliases.

## Figure 3 — transaction and exactly-once publication trace

**Claim support:** GC-C06, GC-C07.

Use the E1/E2 authority sequence:

~~~text
accepted origin
  -> trial
  -> reject/discard             authority unchanged
  -> new trial
  -> coupled convergence
  -> all preflights             authority unchanged
  -> MODFLOW finalize
  -> SWAP commit
  -> ledger commit              exactly one transfer
~~~

Plot/table the authoritative tuple:

~~~text
SWAP revision
SWAP committed time
ledger count
ledger exchange
~~~

at each event.

Rejected attempts must visibly remain zero-authority.

## Figure 4 — E3 numerical interface closure

**Claim support:** GC-C04.

Purpose: show when a one-pass affine predictor fails the strict interface criterion and how many strong-coupling iterations restore it.

Use only the twelve valid low-flux E3 cases.

Recommended separate plot:

- x: coupling-window duration, logarithmic;
- y: absolute loose interface residual / 1e-15 m/s qualification tolerance, logarithmic;
- one series per MODFLOW K;
- reference line at ratio 1.

A second separate figure, not a subplot:

- x: window duration;
- y: strong-coupling outer iterations;
- series per K.

Do not call the ratio a hydrological error.

## Figure 5 — E3 physical impact of enforcing strong coupling

**Claim support:** GC-C11.

Keep this separate from Figure 4.

Recommended plots:

### 5a head correction

- x: window duration, logarithmic;
- y: |H_strong - H_loose| in m, logarithmic;
- series per K.

### 5b exchange correction

- x: window duration;
- y: |q_swap,strong - q_swap,loose|.

The caption must state that even the largest initial E3 head correction is only 5.55e-9 m.

This pair is the visual evidence for:

> strict numerical interface inconsistency can coexist with negligible hydrological state error in the demonstrated weak-feedback regime.

## Figure 6 — predictor qualification envelope

**Claim support:** bounded E3 interpretation and E4 case selection.

A compact heatmap or status diagram:

- x: predictor flux;
- y: coupling-window duration;
- symbol/status: READY or whole-window predictor incomplete.

Mark:

- largest demonstrated READY point;
- smallest tested failure for each window.

Do not interpolate a formal physical boundary from only the tested discrete points.

## Figure 7 — E4 response identity

**Claim support:** GC-C09.

Only after E4 execution.

Use raw derivative curves versus perturbation scale rather than only a selected number.

Separate views:

1. u_FD(delta_q) and u_AT;
2. J_S(delta_H), -J_V(delta_H), and u reference;
3. differentiated balance residual;
4. tangent defect versus delta_H.

The plateau/noise region must be visible.

## Figure 8 — E5 information value

**Claim support:** GC-C10.

Only if E5 is reached.

Compare total equivalent SWAP work for:

- fixed point;
- Aitken;
- IQN/Anderson cold;
- IQN/Anderson warm;
- zero-cost oracle response;
- practical supplied response.

Iteration count alone must not be the y-axis of the primary performance figure.

## Figure 9 — realistic/regional application

**Claim support:** external validity, GC-C13/GC-C14.

Only after E7/E8 evidence exists.

Do not use regional mapping figures to imply physical N:1 aggregation validity; that belongs to SCALE.

# Tables

## Table 1 — relationship to prior coupling approaches

Rows should include:

- HYDRUS-MODFLOW;
- MetaSWAP/SIMGRO;
- OpenMI/HydroCouple;
- MODFLOW API;
- FMI/preCICE;
- IQN/waveform coupling;
- present SWAP5-MODFLOW6 method.

Columns should describe concrete properties, not novelty scores:

- component solver autonomy;
- iterative coupling;
- rollback/replay;
- hydrologically typed quantities;
- explicit accepted/trial state authority;
- exactly-once whole-window mass publication;
- component-provided response;
- multirate/internal timestep autonomy.

Avoid a "winner" framing.

## Table 2 — coupling quantities and conventions

For every public quantity state:

- symbol;
- physical meaning;
- native/public sign;
- unit;
- time support;
- owner;
- authoritative publication point.

Minimum rows:

~~~text
H
pressure head
q_bot
q_u / q_swap
u
V_out
DeltaS
~~~

## Table 3 — evidence envelope

Columns:

- experiment;
- real SWAP?;
- live MODFLOW?;
- window range;
- forcing/state range;
- active processes;
- mapping;
- result status;
- claim supported;
- explicit exclusions.

This table should prevent readers from mistaking runtime architecture coverage for scientific envelope coverage.

## Table 4 — E3 numerical results

Do not print all 48 raw cases in the main paper.

Main table should summarize:

- valid case count;
- predictor failures;
- iteration range;
- max loose residual;
- max relative loose mismatch;
- max head correction;
- max q correction.

Put the complete machine-readable matrix in repository/supplementary material.

## Table 5 — E4 identity summary

Only after E4.

Per baseline:

- u_AT;
- u_FD plateau estimate;
- J_S;
- J_V;
- J_B;
- repeatability/noise status;
- derivative plateau status;
- linearity range.

# Current figure readiness

~~~text
F1  method architecture             READY TO DRAFT
F2  interface quantities            READY TO DRAFT
F3  transaction trace               DATA READY
F4  E3 interface closure            DATA READY
F5  E3 physical impact              DATA READY
F6  predictor envelope              DATA READY
F7  E4 response identity            WAIT E4
F8  E5 information value            WAIT E5
F9  realistic/regional application  WAIT E7/E8
~~~

The next actual manuscript graphics should therefore be F3–F6, not a speculative architecture beauty figure.
