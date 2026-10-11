# F-MIG431-INT13 source reconciliation addendum

Date: 2026-10-05

This addendum preserves the original preregistration while correcting its
source premise. The preregistration used SWAP 4.2.0 Rutter because the exact
B1.11 source archive had not yet been materialized. Recovery of the release
archive established that its exponential `fimin` equation is not the B1.11
Rutter method. The earlier INT13 analytic candidate and its qualification
claim are superseded.

## Recovered authority

The recovered `SWAP_4.3.1(5).zip` has SHA-256
`2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`; its
nested `SWAP.ZIP` has SHA-256
`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. The B0
archive verifier matched all 63 members and reported manifest SHA-256
`d923ac9aa474e9ef78cd8c5c51a9ca6ce6b4fb549a61180461da04ce1af4922f`.
Applying the recorded SWAP-006 patch to B0 `MOD_meteo.f90` yields the
reconstructed B1.11 member with SHA-256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.

The B1.11 `Rutter` routine sets `flux_in = rpd*vcover` and `flux_out = eintc`.
It applies those rates while the canopy fills or drains, computes the time to
capacity or dryness from the storage difference divided by the net flux, and
uses equal input and output rates after reaching a boundary. When dry and
`flux_in < flux_out`, it limits outflow to inflow and computes wet fraction as
`flux_in/flux_out`. `fimin` is absent from this B1.11 routine.

## Candidate and evidence

The source-window integrator now resolves these internal fill/dry regimes
inside each immutable atmospheric-forcing window. It returns interval-average
fluxes and storage without making those events Richards timestep requests.
The `fimin` fields were removed from the Rutter input and from immutable
window identity. Capacity reductions release excess water to surface
throughfall as an explicit SWAP5 transition.

Current local checks passed:

- `tests/fpm/run_f_mig431_int13_rutter_source_window.sh`, O0/O2 output
  identical, including hand-computed B1.11 fill/full and drydown cases.
- `tests/fpm/run_f_mig431_int13_capacity_event.sh`, O0/O2 output identical.
- `tests/fapp/run_ppa_wu01_production_application_bootstrap.sh`, O0/O2 output
  identical, including FMR transactional commit and retry composition.

Targeted GitHub Actions run `37271615834` passed both the INT13 Rutter physics,
source-window, retry and restart gate and the FMR production-composition gate
on candidate commit `4403db7996ec49b910a419d53c7efe2b4cd75102`. Historical run
`37268521592` tested the superseded `fimin` candidate and is not evidence for
this source correction.

This qualifies only the bounded candidate and tested compositions. It does not
admit `SWINTER=3` canonically. Constant surface irrigation has since been wired through both B1.11 `ISUA` partitions. Local O0/O2 tests cover proportionate intercepted rain/irrigation, rain-only interception with irrigation pass-through, immutable irrigation forcing within a source window, and FMR production with both modes at the tested low-rate vector (0.01 cm/day irrigation with 0.2 cm rainfall per source window). Targeted Actions run `37276517425` passed the INT13 physics/source-window/retry/restart/determinism and production FMR composition/preservation gates on commit `6f6eba2241b662cf0d3c1126bd21a63845b6ee41`; companion PPA-WU01 run `37276517357` also passed. The persisted envelope is limited to the tested low-rate constant-irrigation vector and both `ISUA` modes. Higher tested irrigation-throughfall forcing triggers `HeadCalc: dynamic head regime omitted surface-head derivative` and remains excluded. Irrigation scheduling, sprinkling, Snow, Black/Boesten with Rutter, macropore, drainage, RFM/surface water, root compensation and unsupported solver profiles remain outside the qualified envelope.

## Persisted bounded irrigation requalification

The exact candidate tree `a523b26932bf95d5cd773e88b85ae1c34896645d` was tested at remote commit `6f6eba2241b662cf0d3c1126bd21a63845b6ee41`. INT13 Actions run `37276517425` passed physics, source windows, retry/restart/determinism, production FMR composition and preservation. Companion PPA-WU01 owner run `37276517357` passed. This qualifies constant surface irrigation at 0.01 cm/day with 0.2 cm rainfall per source window under both B1.11 `ISUA` partitions, within the documented Reference Richards and process envelope. It does not admit `SWINTER=3` canonically or extend the claim to high-throughfall irrigation, schedules or sprinkling.
