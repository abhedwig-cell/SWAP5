# F-ROMV2 D15 FMC surface-accounting adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D15  
**Decision:** **D15_FMC_FULL_SURFACE_ACCOUNTING_PREFLIGHT_PASS**

## Question

D15 closes the accounting gap that remained after D14.

D14 showed that the literature-bound infiltration-front and falling-slug
kinematics are finite and conservative in isolation. D15 asks whether the
state transitions needed around those kinematics can also be expressed as a
closed finite-volume water ledger before any SWAP trajectory is exposed.

The answer is positive.

## Authority boundary

D15 retains:

- the 200-bin moisture discretization frozen in D12;
- the maximum 10 s explicit process step frozen in D12;
- the D14 Eq.18 infiltration-front kinematics;
- the D14 Eq.19 falling-slug translation;
- Ogden-2015 capillary relaxation.

For surface allocation it follows the Talbot-Ogden sequence:

1. surface input is a finite water depth;
2. bins are considered from lower to higher water content;
3. existing fronts consume water according to their calculated advance;
4. dry-bin initiation uses a one-bin Green-Ampt root;
5. water remaining after the active domain is satisfied becomes ponding or
   runoff according to the selected boundary condition.

D15 deliberately does **not** reinstate the 2008 capillary-weighted
redistribution operator. Ogden et al. (2015) superseded that process for the
general method with conservative capillary relaxation.

## Immutable execution

Workflow run **35455721244**, job **105930504818**, executed head
`58ee8e9367f5338758477a3a3e17bdbaa3082c11`.

Artifact:

- ID: **10587992420**
- digest:
  `sha256:33bbd2075ceebbdfaa97aee0c88ccf05c565c4f6092dcfa12bfdc531575b1912`.

No SWAP trajectory evidence was consumed.

## A1 — supply-limited existing fronts

A finite rainfall supply of approximately **0.00090350 cm** is allocated
left-to-right across the D14 I_MID front family.

The supply is exhausted inside bin 128.

Column storage increases by the same supplied depth, with ledger residual about

**-1.42e-16 cm**.

This verifies partial final-front allocation without borrowing water from a
hidden source.

## A2 — dry-bin activation

The first dry active bin is initiated with the frozen one-bin Green-Ampt root.

Results:

- activation depth: about **0.45913 cm**;
- activation water: about **0.00093545 cm**;
- Green-Ampt root residual: **0.0 cm** at reported precision;
- finite-volume activation ledger residual: **0.0 cm**.

The test is intentionally supplied with more water than required so it
qualifies initiation rather than an ambiguous partial dry-bin state.

## A3 — overflow, surface storage and runoff

A synthetic state with all active bins filled to the 160 cm domain is used to
force overflow.

The active-bin 10 s acceptance capacity is about **0.0417226 cm**.

Two boundary ledgers are tested:

- no ponding: all residual water becomes runoff;
- finite surface store: a store of one (K_sDelta t) is filled first, then
  the remainder becomes runoff.

Both ledgers close exactly at reported precision.

## A4 — hiatus detachment and falling-slug translation

Three connected wetted intervals are converted to falling slugs at zero
surface supply.

Water before detachment, after detachment and after one Eq.19 translation step
is identical:

**0.1833723 cm**.

Maximum slug-length drift is **0.0 cm**.

## A5 — falling-slug / groundwater merge

A same-bin falling slug is placed exactly in contact with a groundwater-filled
interval.

The two occupied intervals are replaced by their finite-volume union.

The occupied length is **140 cm** before and after the merge and the water
residual is **0.0 cm**.

This qualifies the bookkeeping primitive only; it is not yet a coupled
groundwater trajectory result.

## A6 — composite capillary relaxation

A composite state contains both connected fronts and falling slugs. The
connected front set deliberately contains an ordering inversion.

Capillary relaxation restores monotonic ordering while total finite-volume
water remains unchanged:

**0.08964868 cm** before and after.

## A7 — end-to-end pulse then hiatus

A two-stage synthetic sequence combines the accounting primitives:

1. a no-ponding rainfall pulse advances existing fronts;
2. one dry bin is fully activated;
3. the remaining water is insufficient to activate the next dry bin and
   therefore becomes runoff;
4. no surface water remains;
5. a zero-supply hiatus then detaches connected water and applies one
   falling-slug translation step.

Results:

- rainfall: **0.00151583 cm**;
- infiltrated water: **0.00100439 cm**;
- runoff: **0.000511441 cm**;
- bin 103 activated: yes;
- bin 104 activated: no;
- surface water at hiatus start: **0.0 cm**;
- pulse ledger residual: about **-3.04e-18 cm**;
- global pulse-plus-hiatus ledger residual: **0.0 cm**.

This is the strongest D15 result because it demonstrates a closed transition
from atmospheric supply to infiltration/runoff and then to detached mobile
water without a correction flux.

## Scientific meaning

D15 establishes that the frozen FMC atmospheric-side **state and water
accounting** can be made internally closed.

That is distinct from proving hydrological fidelity.

The next question is now legitimate:

> On a bounded homogeneous-B01 infiltration/hiatus workload, does the fully
> assembled FMC surface route reproduce R16 water storage, infiltration,
> redistribution and lower-boundary response better than the already admitted
> R2 coarse-Richards comparator?

D16 may answer that question using exposed development data only.

## D16 boundary

D16 may use:

- homogeneous B01;
- the D12-D15 frozen 200-bin discretization;
- maximum 10 s internal FMC process steps;
- no root extraction or ET;
- R16 and R2 comparators;
- surface rainfall/infiltration/hiatus forcing supported by the published FMC
  authority.

D16 may not:

- retune bin count or process step;
- retune dry-bin Green-Ampt initiation;
- alter allocation order;
- reuse V01-V04 as new blind evidence;
- claim seasonal, ET, coupled-groundwater or production validity;
- make a formal speedup claim.

Application acceptance remains unqualified.

Production ROM remains unauthorized.
