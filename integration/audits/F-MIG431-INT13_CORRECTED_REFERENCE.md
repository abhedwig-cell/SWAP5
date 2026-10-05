# F-MIG431-INT13 Rutter reservoir reference

## Source and version authority

The controlling historical target is SWAP 4.3.1/B1.11. PPA-WU04 records the
corrected B1.11 identities: `MOD_meteo.f90` SHA-256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`,
`swap.f90` SHA-256
`39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`, and
the 63-member manifest SHA-256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

The source is available in Git at
[`SWAP-model/swap-4.2.0/src/meteoday.f90`](https://github.com/SWAP-model/swap-4.2.0/blob/c30e5e4cd3a7427246b5206c15ad6960897d18d3/src/meteoday.f90),
commit `c30e5e4cd3a7427246b5206c15ad6960897d18d3`. The commit identifies its
physics as unmodified SWAP 4.2.0. The fetched source file has Git blob
`90c3a9aae0035b6af3620d006f2224222bae80a8`, SHA-256
`f813b41eec87e076af272e27369cde8539de471812a6f23f3c5b651f67ce1fed`, and
contains `ruttervw`/`msw1eic` at lines 766–1021. It is a genuine SWAP Git
source, but is not itself the B1.11 file. The ordered B1.11 patch chain shows
that SWAP-006 is the only patch targeting `MOD_meteo.f90` and changes the
bounded dynamic-crop meteo-loading loop, not Rutter. The B1.11 B0 archive and
full reconstructed `MOD_meteo.f90` are not materialized in this checkout, so
byte identity between the 4.2.0 Rutter body and B1.11 is not claimed. The Git
source plus the untouched Rutter patch history and the already admitted
F-APP05 process qualification provide the equation basis used here.

## Reconstructed Rutter reservoir equation

For canopy cover `c`, gross rain rate `P`, canopy capacity `C`, storage `S`,
wet-canopy evaporation capacity `Ew`, and input `fimin`, the Git source's
nonlinear branch has

`beta = (1 - fimin) * Ew / C`

`zeta = c * P - fimin * Ew`

`dS/dt = zeta - beta * S`

until the reservoir reaches capacity. The exact solution is

`S(t) = (S0 - zeta/beta) * exp(-beta*t) + zeta/beta`.

When this reaches `C`, the source solves the fill time `tcap` analytically and
uses full `Ew` thereafter. The zero-beta branch is linear and clips at the
physical endpoints. Below `dc=1e-4`, the source has explicit no-flow/dry-store
shortcuts; if capacity falls below `dc`, remaining store is evaporated as the
vegetation dies off. The intercepted precipitation flux follows the hard
balance `Pi = (S1 - S0)/dt + Eic`. The wrapper computes wet-canopy fraction
from `Eic/Ew` when `Ew` exceeds `dc`. `fimin` is a required SWINTER=3 input
(read with bounds 0–1); it cannot be silently inferred from Richards dt.

The source's `tcap` calculation proves that the full SWAP 4.2.0 Rutter routine
does not rely on the Richards caller to split a precipitation interval at the
reservoir-fill event. The previous INT13 audit incorrectly promoted the
short-interval SWAP5 `evaluate_rutter_interval` clipping result as evidence of
a B1.11 physics defect. That API falsifier is retained only to show why it
cannot own a long source window. No historical B1.11 mass-loss defect is
claimed.

## SWAP5 reference and intentional differences

The unchanged, admitted `evaluate_rutter_interval` process remains the bounded
F-APP05 short-interval API. The new source-window path uses the analytic
reservoir equation above directly: it computes the fill time within each
immutable forcing window, returns interval-average throughfall, canopy
storage, evaporation and wet-canopy fraction, and does not couple event
progress to Richards steps. Missing `fimin` fails closed. When positive
capacity decreases, excess storage is booked once as canopy-to-surface water;
when capacity falls below the legacy dry-capacity cutoff, residual storage
follows the historical vegetation-death evaporation branch. Existing
F-APP05 behavior and source blob remain unchanged.

For constant forcing, the exponential reservoir solution is a semigroup: one
source interval and any partition into smaller source intervals must produce
the same final storage and integrated fluxes. Detailed meteorology therefore
uses one immutable source window per record. LAI/canopy capacity, `fimin`,
wet-canopy demand and irrigation changes must enter at an explicit source
boundary. Richards retries never invoke the source processor again for an
already accepted interval.

## Ownership and transaction

`mod_rutter_source_window_processor` composes the analytic Rutter candidate
with INT12 immutable source progress. One FMR physical-state candidate carries
both canopy storage and accepted source progress. Production prepares forcing
from the accepted snapshot before Richards execution. The enclosing
per-column FMR transaction publishes the candidate only when the hydraulic
candidate is accepted. A rejected hydraulic trial cannot change accepted
Rutter state or replay precipitation. Restart export/restore carries the
canopy store and source progress together.

## Qualification and claim ceiling

`F-MIG431-INT13_LOCAL_QUALIFICATION.json` records strict GNU Fortran O0/O2
local evidence for fill/overflow `tcap`, the independent `fimin` exponential
oracle, dry-down, changing capacity, water closure, source-window refinement,
reject/retry identity, restart, detailed-record continuation and production
binding. The separate FMR bootstrap test verifies transactional commit and
Richards retry composition. PR #1016 recovery head `d853fd898db629100ab52493b1e6f13208af9bb4` restores the FMR backend source (blob `43cd6e413e23ce420bdfda8547a7fdb8472158d9`). Targeted Actions run `37268521592` passed both the Rutter physics/retry/restart gate and the production FMR composition gate. This qualifies the tested bounded candidate; it does not establish canonical admission or byte identity with the full B1.11 member.

The exact B1.11 full member/call-site has not been reconstructed byte-for-byte,
and the newly corrected analytic implementation therefore remains a candidate,
not a canonical admission. The admitted envelope remains fail-closed for
irrigation/sprinkling, Snow, Black/Boesten, macropore, drainage, RFM/surface
water, root compensation, unsupported solver profiles and numerical
continuation. The existing `SWINTER=0/1/2`, Black, Boesten, F-APP05 and F-APP08
claims are not broadened by this work.
