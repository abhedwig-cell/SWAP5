# F-ROMV2 D14 FMC surface-kinematics adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D14  
**Decision:** **D14_FMC_SURFACE_KINEMATICS_PREFLIGHT_PASS**

## Question

D14 asks whether the atmospheric-side finite-moisture-content kinematics are
internally coherent before any full rainfall-allocation algorithm or SWAP
trajectory comparator is allowed.

The test is deliberately upstream of application fidelity. It exercises only
the literature-bound infiltration-front and falling-slug kinematics using the
D12-frozen B01 constitutive identity, 200 moisture bins and maximum 10 s
explicit process step.

No SWAP trajectory evidence is consumed.

## Primary authority

D14 is bound to:

- Ogden et al. (2015), *Water Resources Research* 51, 4282-4300,
  doi:10.1002/2015WR017126;
- Talbot and Ogden (2008), doi:10.1029/2008WR006815;
- Ogden et al. (2017), *The Soil Moisture Velocity Equation*,
  doi:10.1002/2017MS000931.

The implementation is clean-sheet research code. No external source code is
copied or executed.

## Immutable execution

Workflow run **35452867795**, job **105922955937**, executed head
`25e2d39db6eb5638c9e27520002886197de73e49`.

Artifact:

- ID: **10587342866**
- digest:
  `sha256:c8fade42571ebe039085acd1f88f2e9067733bdd5fd89757ce24ca092800a61b`
- raw result SHA-256:
  `cb2149f837f2b2821bedf24bcd274d819d0751026be274153129d4681f8e9e9a`
- stdout SHA-256:
  `85d78a7453d2573fd8d76eaa3f483c96a3456b6818bfe0601b0b4a9ee4a96446`.

## Infiltration-front result

All four frozen Eq.18 front families complete with finite physical front
positions and positive surface-water demand.

The deliberately shallow I_RELAX case produces **35 raw front-order
inversions** under the frozen 10 s explicit step. The preregistered capillary
relaxation then restores monotone front ordering.

Critically, sorting changes finite-volume storage by exactly **0.0 cm** at
reported precision.

For every infiltration case, the unlimited-reservoir surface ledger closes
exactly at reported precision:

[
Delta S_{column} - W_{surface}=0.
]

The largest synthetic 10 s water demand occurs in I_RELAX and is about
**0.096285 cm**.

This qualifies the kinematic update plus conservative relaxation. It does not
yet qualify finite rainfall allocation.

## Falling-slug result

The Eq.19 falling-slug translation is exercised for all 99 active bins.

Results:

- every velocity is finite and positive;
- maximum 10 s translation is about **0.15546 cm**;
- maximum absolute slug-length change is about **3.55e-15 cm**;
- total finite-volume slug-water difference is exactly **0.0 cm** at reported
  precision.

Thus gravity-driven translation itself preserves slug water to floating-point
resolution.

## What D14 proves

D14 establishes that the frozen FMC atmospheric-side kinematic primitives can
be evaluated consistently for B01:

1. multi-bin infiltration-front advance;
2. capillary relaxation that restores ordering without changing water volume;
3. an exact synthetic surface-reservoir ledger;
4. falling-slug translation;
5. falling-slug storage preservation.

That is enough to justify a full surface-accounting preflight.

## What D14 does not prove

D14 does **not** qualify:

- supply-limited rainfall allocation;
- sequential wet-bin activation;
- dry-bin front initiation;
- ponding or runoff;
- falling-slug creation;
- slug collision or merging;
- slug/groundwater-front merging;
- redistribution water transfer between bins;
- groundwater-front interaction during surface forcing;
- any SWAP infiltration trajectory;
- ET or root uptake.

Those are not small implementation details. They determine whether the
front-based representation remains a closed water ledger when atmospheric
supply changes regime.

## D15 authority

D15 is authorized only as a separate preflight of the missing finite-volume
surface accounting.

It may reconcile and test:

- finite rainfall supply against infiltration demand;
- sequential left-to-right activation of dry moisture bins;
- explicit surface reservoir / ponding bookkeeping;
- formation and conservative translation of falling slugs;
- collision/merge accounting;
- conservative merge with the groundwater-front state;
- redistribution bookkeeping between moisture bins.

D15 may not yet run a SWAP surface-infiltration comparator.

Only after all of those accounting identities pass without hidden correction
may a new workunit preregister exposed development trajectories.

The D12 bin count, D12 maximum process step and D14 kinematic equations are
frozen. They are not tuned from D15 outcomes.

## Boundary

D14 provides **kinematic authority**, not application acceptance.

It makes no formal speedup claim and changes no production or Reference source.

Production ROM remains unauthorized.
