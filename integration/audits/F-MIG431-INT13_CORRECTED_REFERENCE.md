# F-MIG431-INT13 Rutter reservoir reference

## Source and version authority

The controlling historical target is SWAP 4.3.1/B1.11. PPA-WU04 records the
corrected B1.11 identities: `MOD_meteo.f90` SHA-256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`,
`swap.f90` SHA-256
`39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`, and
the 63-member manifest SHA-256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

The exact B1.11 release archive was recovered from the project Library and
materialized outside the repository. Its outer archive SHA-256 is
`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`; the
nested `SWAP.ZIP` SHA-256 is
`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. The
verified B0 member manifest contains 63 members and has SHA-256
`d923ac9aa474e9ef78cd8c5c51a9ca6ce6b4fb549a61180461da04ce1af4922f`.
Applying the recorded SWAP-006 patch to the exact B0 `MOD_meteo.f90` produces
the B1.11 source with SHA-256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.
The archive verifier passes all 63 members. The full extracted file is
`source_recovery/B1_11_MOD_meteo.f90` in the workspace, not a repository
artifact. This replaces the earlier, insufficient 4.2.0-only source claim.

## Reconstructed Rutter reservoir equation

The authoritative routine is B1.11 `MOD_meteo.f90:Rutter` (lines 2201–2303).
For cover `vcover`, rain/irrigation precipitation rate `rpd`, canopy storage
`sicact`, capacity `siccap`, and interception evaporation `eintc`, it sets
`flux_in = rpd*vcover` and `flux_out = eintc`. If `flux_in >= flux_out` and
storage is below capacity, the canopy receives those two constant fluxes until
`(siccap-sicact)/(flux_in-flux_out)`, then becomes full; at capacity, in- and
outflow are both `flux_out`. If `flux_out > flux_in` while storage is positive,
the same constant fluxes continue until `sicact/(flux_out-flux_in)`, then the
canopy is dry. At zero storage, in- and outflow are both `flux_in`, and wet
fraction is `flux_in/flux_out`. The routine therefore uses piecewise constant
fluxes and fill/dry event times. It does not use the 4.2.0 `fimin` exponential
ODE. `ProcessMeteoDT` then partitions the interval's gross rain and irrigation
using the intercepted flux; `integral.f90` advances `sicact` from the flux
difference.

The exact routine's fill/dry event times establish why a source-window
processor must resolve its internal process transitions itself. They do not
make those events Richards timestep requests. The previous INT13 audit used
the wrong 4.2.0 equation and incorrectly treated `fimin` and analytic `tcap`
as B1.11 physics. That implementation and its old qualification are
superseded.

## SWAP5 reference and intentional differences

The source-window path now implements B1.11's piecewise constant flux regimes
and resolves fill/dry events inside each immutable forcing window. It returns
interval averages and candidate storage without coupling event progress to
Richards steps. The `fimin` input was removed because B1.11 does not use it.
Storage above a reduced capacity is transferred once to surface throughfall,
preserving water. This capacity-change transfer is an explicit SWAP5 state
transition, not an assertion that the B1.11 Rutter routine itself performs
that transfer.

For constant forcing, the piecewise-linear reservoir solution composes across
source intervals: one source interval and any partition into smaller source
intervals must produce the same final storage and integrated fluxes. Detailed meteorology therefore
uses one immutable source window per record. LAI/canopy capacity, wet-canopy demand and irrigation changes must enter at an explicit source
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

Local GNU Fortran O0/O2 tests now exercise fill/overflow, constant-flux drydown,
capacity change, mass closure, source-window refinement, reject/retry,
restart, detailed-record continuation and production binding. The separate FMR
bootstrap test verifies transactional commit and Richards retry composition.
Targeted Actions run `37271615834` passed the Rutter physics/source-window/retry/restart and production FMR gates on candidate commit
`4403db7996ec49b910a419d53c7efe2b4cd75102`. Historical run `37268521592`
tested the now-superseded 4.2.0-derived implementation and is not qualification
evidence for the B1.11-equivalent candidate. See the source-reconciliation
addendum for the claim ceiling.

The exact B1.11 full member/call-site has been reconstructed and its member
hash verified, and the bounded B1.11-equivalent implementation has now passed the independent source-derived oracle and persisted qualification in INT13 Actions run `37276517425` on commit `6f6eba2241b662cf0d3c1126bd21a63845b6ee41`. It remains a qualified candidate, not a canonical admission. The persisted extension covers constant surface irrigation under both B1.11 `ISUA` partitions in the tested low-rate production vector; companion PPA-WU01 run `37276517357` also passed. It does not qualify irrigation scheduling or sprinkling. Higher tested irrigation-throughfall forcing reaches the separate Reference Richards dynamic-head error `HeadCalc: dynamic head regime omitted surface-head derivative`; keep that case outside the envelope. Snow, Black/Boesten, macropore, drainage, RFM/surface water, root compensation, unsupported solver profiles and numerical continuation also remain outside the envelope. The existing `SWINTER=0/1/2`, Black, Boesten, F-APP05 and F-APP08
claims are not broadened by this work.
