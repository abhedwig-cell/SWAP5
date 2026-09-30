# F-MACRO-ALT05..07 — parameter reduction and reduced-model architecture

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_DIRECTION / HARNESS_PERSISTED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Executive result

The research line has now moved beyond legacy-state reduction.

The leading alternative is a staged **Reduced Functional Macropore model (RFM)** that preserves the process roles required by SWAP while replacing much of the discrete geometry and surface partition parameterization.

The proposed decomposition is:

```text
SOURCE / MATRIX STATE
        |
        v
  ACTIVATION
        |
        v
 PREFERENTIAL INPUT
        |
        v
 CONNECTIVITY / TERMINATION
        |
        v
 FAST TRANSFER + STORAGE
        |
        +--> MATRIX EXCHANGE
        +--> RAPID DRAINAGE
        +--> DEEP/BOTTOM FLUX
```

The most important design rule is that these reductions are introduced sequentially and falsified separately. Transfer physics is not changed in the first geometry/activation experiment.

---

# ALT05 — continuous connectivity instead of discrete IC subdomains

## Legacy role

SWAP distinguishes:

- Main Bypass (MB): continuous preferential pathways;
- Internal Catchment (IC): terminating pathways;
- multiple IC subdomains ending at different depths;
- optional Ah termination;
- shape controls such as `POWM`, `SPOINT`, `SWPOWM`, `RZAH`, `NUMSBDM`.

This captures a physically important concept: not every preferential pathway remains connected to the same depth.

The research conclusion is therefore **not** to remove connectivity.

It is to replace a discrete set of subdomains by a continuous endpoint-depth survival function:

```text
C(z) = P(Z_end >= z)
```

where `C(z)` is the fraction of terminating preferential pathways that remain connected at depth `z`.

## Why this is physically defensible

Preferential-flow literature identifies long-range connectivity/continuity as a key control on preferential transport. Observable pore aperture alone is insufficient because hydraulically effective paths depend on network continuity.

The continuous survival representation preserves precisely this function while avoiding an arbitrary number of discrete IC subdomains.

## First candidate family

For the first falsification use a two-parameter Weibull survival:

```text
C_IC(z) = exp[-(z/L_c)^p_c]
```

with:

- `L_c`: characteristic connection depth;
- `p_c`: shape/spread.

A separate measured/known Ah termination fraction may be retained if required.

This is not asserted as the final functional form. Its purpose is to test whether the detailed discrete geometry contains information beyond a smooth endpoint-depth distribution.

## Numerical compression screen

The SWAP manual Figure 6.7 example gives five terminating endpoint depths:

```text
85.0, 54.2, 35.6, 26.9, 25.0 cm
```

for four IC subdomains plus the Ah subdomain.

The persisted research harness fits these five endpoints with a deterministic two-parameter Weibull survival.

An independent numerical screen before persistence found approximately:

```text
L_c ~ 50 cm
p_c ~ 1.9
RMS survival mismatch ~ 0.09
```

relative to the deliberately stepwise five-domain representation.

This is already enough to establish **compression feasibility**: two continuous shape parameters can reproduce the broad vertical connectivity pattern of a five-endpoint representation.

The residual mismatch is not considered error against physical truth because the discrete subdomains are themselves a numerical/functional representation.

## ALT05 decision

```text
KEEP: distinction continuous vs terminating pathways
TEST REMOVAL: explicit IC subdomain count and individual subdomain states
REPLACE CANDIDATE: continuous endpoint-depth survival C(z)
```

---

# ALT06 — activation from matrix infiltrability distribution

## Legacy surface partition

In current SWAP theory direct precipitation/irrigation/snowmelt input to macropores at the surface is proportional to surface macropore area:

```text
I_pr = A_mp * P
```

with additional ponded/runoff inflow when the top boundary ponds.

This makes surface macropore geometry directly control direct input.

## Alternative hypothesis

Nimmo's matrix-infiltrability framework instead treats preferential-flow initiation as a consequence of spatial variation in the matrix capacity to accept input.

Let local matrix infiltrability be:

```text
B ~ LogNormal(mu_B, sigma_B)
```

For source intensity `R`:

```text
q_matrix = E[min(R, B)]
q_pref   = R - q_matrix
```

For a lognormal `B`, this partition has a closed form and adds essentially no runtime cost.

## Parameter-reduction strategy

Do not introduce both lognormal parameters as arbitrary calibration parameters if avoidable.

Candidate contract:

```text
b50 = derived from current top-matrix hydraulic/infiltration capacity
sigma_B = one structural heterogeneity parameter
```

Then activation responds automatically to:

- rainfall/irrigation intensity;
- matrix wetness/hydraulic state through `b50`;
- structural heterogeneity through `sigma_B`.

The research harness demonstrates the expected continuous transition. With illustrative `b50=8` and `sigma_B=0.65`, the preferential fraction is approximately:

```text
R=1   -> ~0 %
R=4   -> ~4 %
R=8   -> ~18 %
R=15  -> ~42 %
R=30  -> ~68 %
R=60  -> ~84 %
```

These values are a mathematical sanity example, not a soil calibration.

## Scientific advantage

This activation rule separates two things that legacy geometry partially mixes:

1. **Can the matrix accept the applied water now?**
2. **If water enters fast pathways, how far are those pathways connected?**

That separation is central to the new model.

## Important status

ALT06 changes physical parameterization.

It is therefore **not** an exact-state reduction and may never silently replace reference SWAP behaviour.

It must first be tested as new physical research against:

- current SWAP reference behaviour;
- event-scale observations;
- preferential-flow signatures such as nonsequential wetting and rapid arrival at depth.

---

# ALT07 — staged Reduced Functional Macropore model

## RFM-0: reference

Current SWAP macropore implementation.

Purpose:

- scientific reference;
- synthetic experiment generator;
- preservation target where legacy semantics are required.

## RFM-1A: geometry reduction only

Change only IC geometry:

```text
discrete IC subdomains -> continuous C(z)
```

Keep:

- current SWAP surface activation;
- current transfer formulation;
- current exchange formulation including Philip event history;
- current drainage physics.

This isolates H2: geometry reduction.

## RFM-1B: geometry + activation reduction

Use:

```text
continuous C(z)
+ infiltrability-distribution activation
```

Keep transfer and exchange otherwise unchanged.

This isolates the physical consequence of ALT06.

## RFM-2: reduced fast-transfer model

Only after RFM-1A/B are falsified/qualified, test simplified transfer:

```text
dW_p/dt + dq_p/dz = source - exchange - termination - drainage
```

with compact kinematic/source-responsive transfer.

## RFM-3: transit-time surrogate

Storage-free event/transit-time route.

This remains a throughput surrogate for bounded outputs, not the leading general SWAP kernel.

---

# Current minimal persistent-state target

Prior ALT01..04 results reduce the leading state hypothesis to:

```text
persistent:
    fast-domain water/storage W_p(z)
    Philip event sorptivity S_event(z)
    Philip event age tau_event(z)

derived:
    dynamic shrinkage volume
    total domain volume
    active domain-bottom index
    likely wet-wall fraction

worker scratch:
    rate/Jacobian workspace
```

ALT05 additionally seeks to remove the need for multiple persistent IC-domain water arrays by replacing domain identity with a continuous connectivity/termination operator.

---

# Falsification matrix

## G1 — geometry equivalence

Calibrate one `C(z)` on a subset of current-SWAP synthetic events.

Held out:

- dry intense event;
- wet intense event;
- two-event memory sequence;
- deep-connectivity case;
- shallow-connectivity case.

Reject if no single connectivity parameterization can preserve simultaneously:

- arrival-depth timing;
- rapid drainage;
- bottom flux;
- vertical exchange/deposition profile;
- mass balance.

## G2 — parameter transferability

A geometry reduction fails if `L_c,p_c` must be re-fitted for each rain event.

Geometry parameters must transfer across forcing and initial moisture states.

## G3 — activation transferability

ALT06 parameters must transfer across rainfall intensities and antecedent matrix states.

Reject if `sigma_B` becomes an event-specific tuning factor.

## G4 — state/history preservation

RFM-1A/B must preserve the already established two-value Philip event history where sorptivity absorption is enabled.

## G5 — hard balance

No candidate advances if accepted whole-column water balance fails.

---

# Parameter-count target

The eventual reduced general model should aim for a small functionally interpretable parameter set.

Candidate free/effective parameters:

```text
sigma_B       activation heterogeneity
f_MB          fraction of effectively continuous pathways
L_c, p_c      terminating-path connectivity distribution
a_p, n_p      fast-transfer law, only if later reduction is needed
exchange parameters already tied to matrix hydraulics / Philip event physics
```

Where possible:

- `Z_AH` comes from soil horizon data;
- maximum meaningful connectivity depth comes from profile/structural information;
- shrinkage comes from existing soil shrinkage characteristics;
- matrix activation scale is derived from matrix hydraulics.

Thus the target is not “five arbitrary calibration knobs”. It is a small set of functional structural parameters plus quantities derived from existing SWAP soil data.

---

# Literature alignment

The design is consistent with three independent findings in the literature:

1. preferential-flow models range from parsimonious conceptual models to dual-domain process models, so model complexity should follow the required output;
2. long-range connectivity is a primary unresolved control on preferential flow;
3. matrix infiltrability can control initiation/partitioning, while source-responsive film-flow concepts support fast transfer without assuming fully water-filled tubes.

A transit-time formulation remains useful for bounded drain/solute applications but is not selected as the primary general water-balance model.

---

# Decision after ALT05..07

```text
LEADING GENERAL RESEARCH ROUTE = RFM-1A -> RFM-1B -> RFM-2 only if required

RFM-1A:
  first executable target
  geometry reduction only

RFM-1B:
  second target
  new activation physics

TRANSIT-TIME:
  bounded surrogate track

DUAL-RICHARDS:
  scientific upper-complexity comparator, not production target
```

This staged design prevents a successful or failed experiment from being uninterpretable because activation, geometry, transfer and exchange were all changed simultaneously.

## Persisted harness

`tools/research/macropore_alt05_07_harness.py`

The harness uses the Python standard library only and is intended for research screening without GitHub Actions.

## Next large block

Implement RFM-1A as a standalone event-routing prototype, using:

- current SWAP-style activation as input;
- continuous `C(z)`;
- compact fast-domain storage;
- retained two-value Philip history contract;
- explicit mass receipts.

Then compare it against a synthetic stepped-connectivity oracle before coupling it to full SWAP.
