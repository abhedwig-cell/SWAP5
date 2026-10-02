# TOP03 native-profile integration proposal

Status: proposed ownership contract, not production admission. Canonical inspected: `cd03d041f967f1bedc8d1a68d0ed17c71988d50d`. Invariants 3, 7, 11, 13, 14 and 28 remain binding.

## Storage and transaction ownership

Prefer an explicit contact layer in the existing physical soil profile. The distributed component retains every contact-layer pressure head and water content; its elimination is algebraic, with no demonstrated state reduction or runtime benefit. Creating a second production storage owner currently has no justified benefit.

| Quantity | Proposed owner | Accounting rule |
| --- | --- | --- |
| Contact-layer geometry and retention parameters | Validated physical column configuration | Immutable during a trial; physical field parameters require separate qualification |
| Layer pressure heads and water contents | Existing candidate/committed soil state | Advance only on accepted soil steps; rejected trials restore checkpoint |
| Layer storage | Existing soil storage sum, including current matrix-area policy | Count once through layer cell water content times thickness; no extra boundary storage ledger |
| External exchange | External top face of the entire physical profile | Integrate accepted top-face transfer into receipt with existing signed convention |
| Layer/matrix interface transfer | Internal diagnostic | Never book as an additional external receipt |
| Restart | Existing physical-profile checkpoint owner | Require all layer states and immutable configuration identity; component scratch checkpoint is insufficient |

The standalone component experiment owns its layer state outside the soil fixture, so its diagnostic ledger legitimately adds layer storage. That experiment's ledger must not be copied into a native-profile runtime, where soil storage already includes those cells. Adding physical layer thickness and replacing existing cells are different configurations and need separately issued envelopes.

## Elevation and pressure contract

The synthetic experiment uses a layer at z in (0,L), a matrix below z=0 and imposed total head E=H+L. Production must specify the absolute external water elevation and layer position. A uniform datum translation z'=z-L and E'=E-L places the layer top at zero and the interface at -L while preserving pressure heads and fluxes. Groundwater, forcing elevations and geometry must use the same translation. Passing a Ribasim water elevation as H+L without this contract is incorrect. No default synthetic resistance or material is proposed for field use.

## Boundary discriminator

The supplied two-file prospective patch adds default-false `external_surface_head_imposed` to the typed result and skips the closed pond balance only when it is true. It preserves current canonical water-increment, matrix-area and macropore code. The patch is an integration artifact applied only to a detached checkout; central owners must issue and qualify the production seam. Default-false providers remain subject to the pond balance.

## Temporal acceptance and admission

Ordinary BASE still uses exact full/half physical-state identity. The prior TOP03 acceptance recipe was falsified. Component grid comparisons do not authorize a finite production tolerance. A separately issued transient acceptance policy must cover soil state, external top transfer, bottom transfer and storage together, and define accepted-window carrier and receipt semantics. Do not change BASE identity or silently reuse the component budgets.

Admission requires an authorized physical profile and datum, production checkpoint/reject/replay/restart and receipt tests, a qualified transient policy, and resolution of preservation gates. Until then the native-profile route is a reviewable proposal, not an enabled production path.
