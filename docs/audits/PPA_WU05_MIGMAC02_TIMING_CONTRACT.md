# PPA-WU05-MIGMAC02 timing contract

Date: 2026-10-05
Status: `B111_TIMING_RECONSTRUCTED_SWAP5_TRANSACTION_QUALIFICATION_OPEN`
Canonical parent: `9605fbb1622d96f4691117f66264f13b6dd3a47b`

## B1.11 call sequence

1. `MACRORATE(1)` calls `MACROPORE(2)` before computing rates; this path calls
   `MPVOLUME(1)`, which updates geometry from current iterative `Theta`.
2. The same update is available on later rate refreshes, including derivative
   evaluations from the Richards iteration. The macro-rate bundle therefore
   observes geometry associated with each current iterative moisture profile.
3. At timestep completion, `SOILWATER` invokes `MACROPORE(4)` and
   `MACROSTATE`, which invokes `MPVOLUME(2)` after solving. This postsolve path
   restores capacity where macro water would exceed shrunken geometry. Legacy
   intentionally leaves the already computed surface area unchanged by this
   correction.
4. The legacy `MACROSTATEVAR` rollback saves/restores selected volume and water
   arrays but not `VlMpDyCp` or `SubsidCp`. Trial mutation can therefore leak
   through a forced timestep reduction. This is a legacy state-management
   defect, not a required physical behavior.

## SWAP5 transaction contract

For each Reference Richards trial, read accepted dynamic crack history and
accepted moisture history as immutable inputs. Recompute a candidate profile
from the trial moisture, derive candidate geometry and rates, and associate the
candidate with the exact accepted solver receipt. A rejected attempt discards
all geometry and water-return candidates. Only acceptance publishes dynamic
crack history and its derived geometry; restart serializes that accepted
continuation state. The final rate refresh uses converged candidate geometry,
recomputes dynamic surface input, and adds candidate-capacity water return to
the same matrix exchange vector used by the inner Richards callback. Geometry
displacement remains an explicit transfer through the existing shared owner
receipt, so the one-owner mass ledger can close.

SWAP5 evaluates neighboring hysteresis from the same accepted profile
synchronously. B1.11's ascending in-place loop can observe a newly updated
left neighbor and an old right neighbor; eliminating this order dependency is
intentional, but requires wetting-front oracle cases. B1.11's postsolve capacity
restoration and SWAP5's explicit displaced-water transfer are not assumed
equivalent until saturated and shrinking capacity cases close through runtime.

## Qualification required

The initializer translates physical `surface_crack_area_depth_cm` (legacy
`ZnCrAr`) to `NnCrAr` with the exact B1.11 grid-boundary threshold and `IcTopMp`
covered-profile rule. The oracle passes the exact boundary and invalid
out-of-profile cases at O0/O2.

The independent laws and owner transitions, Reference Richards growth/wetting,
per-domain displacement with rapid drainage, discard/smaller retry, A/B/A,
accepted restart and unchanged-geometry identity pass at O0/O2. Preservation
uses repaired physically valid A8/A9/A10 fixtures and the controlling corrected
MIGMAC01 and PERCH20 gates. Source/output scope is recorded in qualification.

## Qualification finding: nonlinear source freezing

Strong capacity contraction exposes the inherited HeadCalc short-step source-freezing
heuristic: a solve can converge against a frozen exchange vector while the final
candidate geometry yields a different receipt. MIGMAC02 requires the current
geometry source and its Jacobian at every nonlinear iteration. The provider
contract therefore advertises whether freezing is permitted (default true for
existing providers); changing crack geometry disables freezing. An enabled law
with zero crack threshold and zero accepted crack history preserves the existing
iteration policy. This is a numerical policy prerequisite, not a second water owner.
