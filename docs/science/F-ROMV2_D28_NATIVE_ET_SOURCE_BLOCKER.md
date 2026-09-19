# F-ROMV2 D28 — native FMC ET state-update external-source blocker

**Decision:** `M2WC70_NATIVE_ET_STATE_UPDATE_ORACLE_EXTERNAL_RETRIEVAL_BLOCKER`

D28 closes the current executable research block on a genuine external source
authority boundary.

## What is already closed

D26 established that modern FMC and SWAP have intentionally different native
root-water uptake allocation:

- SWAP uses spatial rooted-node fractions plus the restricted Feddes
  pressure-head response;
- FMC preferentially removes water from the right-most / wettest
  water-containing moisture bin inside the root zone.

D27 then showed that these model families can remove exactly the same
**total unstressed water depth** with explicit mass accounting while preserving
their spatial non-equivalence.

Therefore the open question is not whether root uptake can be included in a
water ledger.

## What remains unresolved

The primary Ogden et al. (2015) paper states that root uptake can remove water
from:

- surface wetting fronts;
- falling slugs;
- groundwater fronts;

when those water states occupy the root zone.

The paper identifies the right-most water-containing bin as the withdrawal
priority and finite-volume removal as the conservation principle.

However, the prose does not fully specify the native state transition when the
selected bin is represented by several disjoint geometric FMC components.

In particular, it does not unambiguously define:

- component ordering when root-zone water exists in multiple front/slug/GW
  structures;
- partial exhaustion and geometry update when only part of a component lies in
  the root zone;
- the exact post-withdrawal representation used by the authors' eight-month
  rainfall + ET implementation.

Inventing those rules would create a new SWAP-ROM model rather than faithfully
testing the published FMC process.

## Identified implementation oracle

The paper's data/model statement points to the University of Wyoming DataCorral
record M2WC70.

Repository metadata identifies:

- dataset: M2WC70;
- paper DOI: 10.1002/2015WR017126;
- resource:
  `https://pathfinder.arcc.uwyo.edu/publications/Computational_Hydrology/M2WC70/M2WC70.zip`;
- type: ZIP;
- reported size: 230 MB;
- contents: authors' C implementation and the eight-month Panama rainfall/ET
  loam case;
- rights: CC0 / public-domain dedication.

This is the preferred secondary implementation oracle.

It is not an implementation donor: external source code is not to be copied
into SWAP5. Its role is to disambiguate state-transition semantics that can
then be documented clean-room.

## Retrieval due diligence

The dataset page and exact resource URL are retrievable as metadata.

The archive itself is not retrievable through the current execution routes:

1. direct web fetch of the resource times out;
2. the container download route cannot resolve/retrieve the external host;
3. a targeted search did not find a traceable public mirror;
4. re-reading the primary paper confirms the root-uptake process identity but
   does not supply the missing composite-state transition details.

This is therefore an external-source retrieval blocker.

## Authority boundary

Until the source or an equally authoritative implementation description becomes
available, F-ROMV2 does not authorize:

- native FMC root-active trajectories;
- native FMC drought-stress feedback;
- seasonal ET experiments;
- eight-month ET reproduction;
- drought memory/recovery inference;
- application acceptance;
- production ROM.

The D24 hydraulic and D25 shared-host computational-value evidence remain
unchanged.

## Exact restart procedure

When the external source becomes available:

1. verify that the archive corresponds to M2WC70 and record an immutable digest;
2. locate only the root-zone uptake and associated composite FMC state-update
   routines;
3. reconcile the treatment of surface fronts, falling slugs and groundwater
   fronts under root withdrawal;
4. produce a clean-room state-transition specification;
5. preregister a bounded wet/no-stress native root-active trajectory;
6. only after that trajectory closes may drought stress or seasonal ET be
   proposed.

No scientific choice is required before step 1.

Production ROM remains unauthorized.
