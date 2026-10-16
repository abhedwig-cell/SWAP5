# PPA-WU05-MIGMAC02 source reconciliation

Date: 2026-10-05
Status: `SOURCE_RECONCILED_IMPLEMENTATION_AND_PRODUCTION_QUALIFICATION_OPEN`
Canonical parent: `9605fbb1622d96f4691117f66264f13b6dd3a47b`
Corrected reference manifest: `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`

## Authority and reproducible source recovery

The pinned corrected B1.11 member is `SWAP/macropore.f90`, SHA-256
`f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f`;
`SWAP/macrorate.f90` is pinned to
`537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`.
The exact B1.11 macropore member was reconstructed from the verified B0 member
and repository-pinned SWAP-001 patch using
`reference/swap-4.3.1/patches/SWAP-001/apply_and_verify.py`. Its output hash
matches the required B1.11 hash. The recovered file is intentionally not
duplicated in the repository: the checked-in B0 archive manifest plus pinned
patch are the repository's source authority mechanism.

## Reconstructed behavior

`SHRINKPAR(1)` computes the transition moisture ratio as
`-log((C-1)/(A*B))/B` and rejects values above
`theta_s/(1-theta_s)-0.01`. For clay, `SHRINK` uses solid fraction
`1-theta_s`, moisture ratio `theta/(1-theta_s)`, and either `VoidR=MoisR`
above the transition or `max(A*exp(-B*MoisR)+C*MoisR,A)` below it. Relative
shrinkage is `theta_s - VoidR*(1-theta_s)`. This law is now source-bound for
clay option 1; it does not establish peat or other clay input modes.

In `MPVOLUME(1)`, called by `MACROPORE(2)` from `MACRORATE(1)` before rates
and also reached during rate/derivative refreshes, the code recomputes dynamic
volume and subsidence from current trial `Theta`. It only evaluates shrinkage
for non-rigid soil and `theta < theta_s-1e-4`, and clips compartments below
the matrix groundwater level to zero. On wetting (`theta > ThetM1-1e-8`) a
local or adjacent existing dynamic crack changes the critical threshold to
`theta_s`; otherwise the configured crack threshold applies. Subsidence is
`(1-(1-shrink)^(1/GeomFac))*dz`, floored by `SubsidCpMin`; dynamic volume is
`FrArMtrx*(shrink_volume-subsidence)*dz/(dz-subsidence)`. Negative volume
reduces subsidence and is clipped to zero. Capacity, domain partition, active
bottom, and surface area are then recalculated. Surface dynamic area uses
`VlMpDyCp/(dz-subsidence)` at the selected crack-area compartment; static
surface area is added and total area is capped at 0.6 with a minimum-width
cutoff.

`MPVOLUME(2)` is called by `MACROSTATE` after the solved step. If macro water
exceeds reduced candidate capacity, it selectively restores volume based on
the previous-to-current compartment capacity decrease. The source explicitly
does not recalculate surface crack area after this end-step correction.

## State classification and SWAP5 design

| Quantity | Classification | Evidence / implication |
|---|---|---|
| `VlMpDyCp` | Persistent crack-history state between accepted steps | Saved global array; read by wetting hysteresis and neighboring-compartment rule. |
| `ThetM1` | Accepted moisture history | Existing accepted Richards state supplies wetting/drying direction. |
| Shrinkage inputs, thresholds, geometry factor, matrix fraction | Configuration | Reused without persistence. |
| Subsidence, shrinkage fraction, total/domain capacity, bottom, surface area, `KsMpSs` | Derived from current moisture plus history/config | Recomputed by `MPVOLUME(1)`. |
| End-step capacity restoration | Water-capacity constraint | Legacy redistributes capacity decrease so macro water fits; SWAP5 must preserve water and one-owner accounting. |

Legacy `MACROSTATEVAR(2)` restores selected macro state arrays but omits
`VlMpDyCp` and `SubsidCp`, although `MPVOLUME(1)` mutates them during nonlinear
trials. This makes the legacy path order-sensitive on rejected/retried trials.
SWAP5's accepted/candidate separation is the intentional correction: candidate
geometry is derived from immutable accepted crack history for each evaluation,
then published only with the accepted transaction. Synchronous accepted-state
neighbor reads avoid the legacy in-place loop's direction-dependent neighbor
observation.

The SWAP5 owner returns water excluded by candidate capacity to matrix storage
through the existing geometry-return receipt. This preserves total water and
single ownership while avoiding legacy's post-solve capacity mutation. It is a
deliberate transaction-chain adaptation, not yet qualified as equivalent to
legacy's end-step capacity restoration under all saturated-storage cases.

The implementation now carries candidate subsidence with derived geometry and
computes a top surface crack-area fraction from dynamic volume divided by
`dz-subsidence`, plus static area, the 0.6 cap, and minimum-width cutoff. The
standard config initializer maps `surface_crack_area_depth_cm` to legacy
`NnCrAr` with the same `Z(ic)-0.5*DZ(ic)+1e-2 > ZnCrAr` loop and covered-profile
`IcTopMp` rule. The physical input supplies the legacy depth; the grid node is
derived in the shared initializer. The source-bound numeric oracle checks the
boundary and out-of-profile cases. Top input is distributed using configured
top-node domain fractions, matching `ArMpTpDm` ownership.
The operator now derives the current `NodGwlFlCpZo` cutoff from trial pressure
heads and boundary mode using the reconstructed `CALCGWL`/`WATERTABLE`/
`GWLEVEL`/`NODLEV` sequence. The fixed-groundwater mode retains the legacy
`NumNod+1` cutoff; a fully saturated profile cuts at node 1. The operator then
zeros dynamic volume and subsidence below that node. Focused cut-cell tests pass,
but this translation still needs a fixture comparing runtime groundwater-node
selection against compiled B1.11 cases before broad admission.

## Constitutive census and bounded admission

B1.11 `SwSoilShr` selects rigid (0), clay (1), or peat (2). `SwShrInp`
selects direct parameters or fitting from characteristic points. `SHRINKPAR`
prepares Kim clay and Hendriks peat parameters; `SHRINK` evaluates the resulting
void ratio. MIGMAC02 admits direct Kim clay option 1. Peat, alternate fitting,
and mixed rigid/shrinking layers are not claimed by this qualification.
The geometry/transaction chain is shared; future constitutive options must use it.

For clay, solid fraction is `1-theta_s` and moisture ratio is
`theta/(1-theta_s)`. Below the transition, void ratio is
`max(alpha*exp(-beta*moisture_ratio)+gamma*moisture_ratio,alpha)`;
above it, void ratio equals moisture ratio. Relative shrinkage is
`theta_s-void_ratio*(1-theta_s)`. The transition and minimum subsidence are
configuration derivatives. Minimum subsidence is `SHRINK(theta_crack)*dz`.
Peat instead evaluates Hendriks' exponential curve or three linear segments.
These constitutive options are source-censused, not implemented substitutes.

Persistent physical history is accepted dynamic crack volume and macropore
water, plus the admitted sorptivity history. Previous moisture comes from the
accepted matrix state. Subsidence, surface area, conductivity, capacities and
bottom indices can be reconstructed from configuration/current moisture and
accepted crack history; redundant existing capacity/bottom carriers are checked
at the accepted boundary. No second subsidence restart carrier is added.

Dynamic volume changes with moisture, wetting/drying direction, local and
neighbor accepted crack history and the current groundwater cutoff. Shrinkage
reduces matrix cross-section only through the existing immutable static area
fraction; changing dynamic crack volume does not redefine matrix water ownership.
Geometry controls domain capacity/bottoms, wetted exchange views, surface input
partition and rapid-drain capacity. Displaced water enters the existing matrix
source receipt before acceptance, closing the total-water ledger.

The former A8/A9 failure interpretation is superseded: synthetic capacities
left zero matrix area or omitted it; A10 also initialized more water than its
repaired capacity. Those fixture/configuration defects were corrected. The
unchanged-geometry enabled/disabled inner routes compare byte-identically.
Strong contraction additionally falsified inherited short-step source freezing:
the solver could converge against a stale source and fail the final water ledger.
The explicit provider now disables freezing when crack geometry can change.

Qualification uses independent laws/storage oracles and local Reference Richards
transactions at O0/O2. It does not assert whole-model B1.11 output equivalence,
peat admission, generic ponding/runon ownership, RossFast or parallel execution.
See the qualification record for exact postimages, commands and receipts.
