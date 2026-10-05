# PPA-WU05-MIGMAC02 closeout

Date: 2026-10-05
Status: LOCAL_QUALIFICATION_COMPLETE_PENDING_CANONICAL_ADMISSION
Canonical parent: `9605fbb1622d96f4691117f66264f13b6dd3a47b`

## Production scope

Dynamic Kim clay option-1 shrinkage feeds the admitted single-column Reference
Richards macropore chain. Candidate moisture reconstructs subsidence, dynamic
capacity, domain bottoms and top surface area. Existing owners handle exchange,
A9 top input, A10 rapid drainage and geometry displacement. Acceptance publishes
crack history with water; rejection discards both; accepted restart retains both.
No alternate macropore architecture is introduced.

## Evidence

`integration/audits/PPA_WU05_MIGMAC02_QUALIFICATION.json` pins tested source
postimages, compiler, local commands, outputs and scope. Independent numeric
oracles cover dry/wet directions, unchanged and large valid geometry changes.
The runtime gate covers growth, coherent wetting, two-domain displacement with
rapid drainage, accepted-boundary restart, discarded A/smaller B/fresh B/A replay,
and byte-identical O0/O2 outputs. Enabled zero-change geometry is byte-identical
to the same inner route with shrinkage disabled. Total-water tolerance remains
1e-9 cm; Richards equation tolerances remain 1e-12.

## Negative findings and corrections

- Recovered donor source differed from authority. Reconstruction from pinned B0
  and SWAP-001 yielded the exact corrected B1.11 macropore hash.
- Candidate capacity was published without its dynamic history; both now publish.
- Broadcasting node displacement to every domain duplicated water; domain
  displacement now retains its original owner.
- Synthetic static capacity equal to cell thickness gave zero matrix area;
  fixtures now use positive area. Manual configurations supply the same carrier.
- A10 initial water exceeded repaired capacity; physically valid initial water
  restores the controlling preservation gate without changing its outer policy.
- Arbitrary 0.2 cm crack history in each thin cell was not a coherent accepted
  constitutive state. Heavy loading failed nonlinear convergence; lighter loading
  exposed instantaneous full/half temporal mismatch. Wetting qualification now
  starts from cracks derived from accepted dry moisture. The large transition is
  tested independently in the owner oracle; no tolerance was relaxed.
- Legacy short-step source freezing lost final receipt identity during contraction.
  A default-preserving provider policy disables it for changing geometry.
- A diagnostic attempt summed an unavailable candidate and crashed; temporary
  diagnostic code was removed. This was not evidence of production corruption.
- The historical MIGMAC01 active-e2e runner lacked dependencies/configuration;
  admission preservation uses the controlling corrected-source diagnostic gate.

## Physical adaptation and remaining scope

B1.11 mutates crack/subsidence history within a trial without complete rollback,
and restores overfilled capacity postsolve while retaining old surface area.
SWAP5 derives each trial from immutable accepted history, uses synchronous
neighbor history, and transfers excluded water to the matrix during the solve.
These changes preserve intended shrinkage physics and single water ownership;
they do not claim universal legacy output equality.

Peat/alternate fitting, mixed soil laws, official whole-model case equivalence,
additional rapid-drain geometry and surface-owner compositions remain explicit
migration gaps. RossFast, parallel MultiSWAP, salinity and frost are excluded.
