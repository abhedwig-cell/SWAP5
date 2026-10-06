# PPA-WU05-MIGMAC10 — Andelst Boesten/macropore composition

Date: 2026-10-06  
Status: `LOCAL_COMPOSITION_AND_PRESERVATION_PASSED`
Baseline: canonical integration head `ca856e88e582d468a6f40971ce1f2a75e5089c40`.

## Scope

Close the source-relevant `SWREDU=2` Boesten/Stroosnijder soil-evaporation plus
surface-connected macropore composition used by the official SWAP 4.3.1
Andelst case. This is the first MIGMAC10 surface-composition slice and a
dependency for the full-case equivalence gate. Both official Andelst crop
files also set `SWINTER=3` (Rutter), so this slice does not cover the complete
official surface composition. It does not admit Rutter, Snow, Black,
fixed-weir/Ribasim, independent ponding/runon sources, a new top-input owner,
or any wider execution envelope.

## Pinned source and case evidence

- Recovered official `SWAP_4.3.1(5).zip`: SHA-256
  `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.
- The official archive's `macropore.f90`, `boundtop.f90`, `macrorate.f90`, and
  `headcalc.f90` match the corresponding entries in the retained B1.11 source
  manifest. Its bundled `MOD_meteo.f90` does **not** match the B1.11 manifest
  hash and is not used as the Boesten oracle. PPA-WU04B pins the B1.11
  `MOD_meteo.f90` identity and independent upstream ET equation trace; the
  transaction and Boesten equations below follow its accepted source contract.
- That B1.11 source contract states `reduceva` updates the Boesten `spev/saev`
  continuation from potential evaporation, rain and irrigation; `boundtop`
  uses the resulting `reva` in the matrix surface balance while macropore
  surface input remains the explicit `ArMpSs*(NRaiDt+NIrd+Melt)` source plus
  separately owned `QMpLatSs`; `macrorate` partitions that source by domain
  top-area share. These are distinct flux and storage owners that must be
  carried together through the same accepted trial.
- Official `cases/3.macroporeflow/swap.swp` sets `SWREDU=2`,
  `COFREDBO=0.79`, `SWMACRO=1`, `SWSNOW=0`, and detailed rainfall (`SWRAIN=3`).
  Both `wintcer1.crp` and `wintcer2.crp` set `SWINTER=3`; the full case is thus
  a Rutter + Boesten + macropore composition, beyond the currently tested
  Boesten + macropore pair.
  The admitted fixture is `tests/data/ppa_wu05_migmac01/modified_andelst.swp`.
- The corrected Andelst state/rate authority already committed under
  `tests/data/ppa_wu05_migmac01/` remains the reference; new evidence must not
  replace or regenerate it silently.

## Contract to qualify

1. Preserve Boesten `spev/saev` update and evaporation reduction exactly as in
   the corrected B1.11 source.
2. Preserve A9 rainfall/irrigation/melt/lateral macropore input semantics and
   exactly-once external mass booking. Do not infer components from generic
   `top_flux` and do not transfer macropore input into matrix evaporation.
3. Compose both continuation owners in one committed-state/restart layout.
   Rejected trials must leave both Boesten and macropore continuation unchanged;
   replay after rejection and separate-process restart must reproduce the next
   accepted result.
4. Keep matrix and macropore water balances independently observable and close
   the whole-column balance at the existing qualified tolerance.
5. Preserve standalone Boesten, standalone MIGMAC09, A9 and existing A8/A10/
   PERCH20 behavior.

## Remaining source-order contract

The exact B1.11 `ProcessMeteoDT` order is `Rutter()` interception, partition
`aintcdt` into net rain `nraidt` and net irrigation `nird` using `ISUA`, then
`reduceva(nraidt)`. `reduceva` uses `nraidt+nird` as Boesten wetting. The
source equations establish the needed surface split: `boundtop` forms the
matrix supply from `(nraidt+nird+melt)*(1-ArMpSs) + runon - reva - epd`, while
`macrorate` supplies macropores from `ArMpSs*(nraidt+nird+melt)` plus the
separately owned lateral overland source `QMpLatSs`. The source files match
the retained B1.11 manifest (`boundtop.f90` SHA-256
`69d0d4703af64212d7200898f12568853d015cea29cb45f81915bece15b63c04`,
`macrorate.f90` SHA-256
`537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7`).

This yields an explicit routing contract. First calculate post-Rutter net
rain and irrigation in the source's `ISUA` order. Feed their unsplit sum to
Boesten wetting. For infiltration, send the matrix-area-weighted direct input
`(1-ArMpSs)*(nraidt+nird+melt)` through the matrix dynamic-top provider and
send `ArMpSs*(nraidt+nird+melt)` through the A9 macropore top-input owner;
their sum must recover the post-interception direct input. Keep `runon`,
`reva`, `epd`, and `QMpLatSs` under their distinct owners. The residual-synchronous candidate-area handoff now solves the geometry part
for Boesten plus macropore input, including shrinking profiles. Rutter remains
uncomposed. Its dynamic top provider is currently bound before the Boesten
process is evaluated and later replaces the Boesten provider. A combined path
must preserve Rutter's post-interception net rain and irrigation while also
passing the Boesten-reduced bare-soil evaporation demand. Otherwise it silently
bypasses Boesten even if the three continuation states are persisted correctly.
The Rutter net direct rates must feed both the Boesten wetting calculation and
the macro/matrix area split from the same candidate `ArMpSs`.

`HeadCalc` calls the dynamic top-boundary callback before the later macropore
rate evaluation. The inner macropore provider now supplies candidate `ArMpSs`
from the full current profile at that callback boundary when the shared-source
option is active. The dynamic top provider uses
`1-ArMpSs` for direct rain, irrigation and melt, while the macro top-input
carrier uses `ArMpSs`; runon, lateral input and evaporation keep their separate
owners. The accepted profile and geometry are not changed by this trial-local
handoff. This route has passed HeadCalc/FMR transaction tests for static and
shrinking geometry at O0 and O2, including reject/replay and restart. The wider
Rutter composition and full Andelst comparison remain separate gates.

The first experimental Rutter + Boesten + macropore route now exists behind a
new, explicit three-owner optional-state layout. Its FMR trial uses Rutter
post-interception rain/irrigation for Boesten wetting and the candidate-area
matrix/macropore split, and rebinds the dynamic top provider with Boesten's
reduced bare-soil evaporation demand. The O0/O2 integration matrix now checks
that each post-Rutter rate reaches Boesten wetting and the macropore input once,
that the matrix/macropore partition is active, and that committed Rutter
  progress reaches the source-window endpoint. Static and shrinking geometries
  pass; the temporal full/half path records rejections, discarded candidates
  leave the accepted state unchanged, and the smaller rerun matches a fresh
  backend. Kernel persistence restore reproduces the next accepted continuation,
  including Rutter progress. A competing caller-supplied macropore source is
  rejected without changing committed state. Whole-column residual remains
  below `1e-9 cm`.
These are focused local qualification results, not production admission or full
Andelst equivalence.

## Residual-synchronous interface spike

The macropore rate provider returns its candidate surface-area fraction to
`HeadCalc` before the dynamic top boundary is evaluated. In the FMR inner
Richards route, this shared-source option is enabled when supplied macro
surface input and a dynamic top provider are both present. The dynamic top
provider applies the complementary matrix share to direct rain, irrigation and
melt. Static and shrinking HeadCalc/FMR trials, reject/replay and restart pass
at O0 and O2, with explicit assertions that the shared partition was active.
The generic boundary flag remains opt-in for other callers. This evidence does
not establish the Rutter + Boesten + macropore composition or full model
equivalence.

## Required evidence before admission

- Exact B1.11 source oracle for Boesten continuation update and the Andelst
  `SWREDU=2` option vector.
- Combined Rutter + Boesten + macropore transaction: post-interception net
  rain/irrigation, Boesten wetting and reduced evaporation, candidate-area input
  split, accepted/rejected trial, replay, restart, and whole-column closure at
  O0/O2.
- Focused legacy preservation: standalone Boesten and prior A9/A10/MIGMAC09/
  PERCH20 gates whose dependency surface changes.
- Only after this composition is qualified: run the full official Andelst
  case and compare the preregistered state, flux, storage, drainage, profile,
  restart and water-balance outputs. That whole-model result is a separate gate;
  this slice alone cannot establish full equivalence.

## Current implementation evidence

- Added the explicit `BOESTEN_MACROPORE` optional-state identity and a committed
  carrier that clones both the Boesten pair and macropore continuation.
- The serialized Reference trial now admits this exact composition and the A9
  supplied top-input path remains separately owned. Other surface combinations
  remain outside this layout.
- `WU05_MIGMAC10=1 bash tests/fpm/run_ppa_wu05a9_top_input.sh` passed at O0 and
  O2, including A7/A8/A9 regression gates and explicit MIGMAC10 static and
  shrinking geometry trials with the same-residual partition asserted active.
  Both variants passed reject/replay and restart checks, and their O0/O2 output
  was identical. Whole-column water closure remained within the runner's
  `1e-9 cm` gate.
- `WU05_MIGMAC10_RUTTER=1 WU05_MIGMAC02_DYNAMIC=2 WU05_MIGMAC10=1 WU05A9_ONLY=1 bash
  tests/fpm/run_ppa_wu05a9_top_input.sh` passed at O0 and O2. The integrated
  runner now includes explicit Rutter + Boesten + macropore trial, reject/retry/
  replay and persistence-restart checks for static and shrinking geometry.
  Assertions compare Rutter net rain/irrigation with both Boesten wetting and
  the macro input carrier. Whole-column water closure and candidate isolation
  are checked in the same trial. O0/O2 marker:
  `PPA_WU05_MIGMAC10_BOESTEN_MACROPORE_O0_O2_IDENTITY=PASS`; combined lifecycle
  markers are printed for both geometry modes.
- Qualification remains open: broaden fail-closed negative tests beyond the
  competing caller-supplied macropore source, run preserved capability gates
  affected by the backend change, and complete the full official Andelst
  comparison.
  The packaged executable still needs Intel `libimf.so`, and the recovered
  archive's `MOD_meteo.f90` is not the pinned B1.11 source identity.

## Interface and architecture boundary

The three-owner experimental route now has a dedicated optional-state identity
and candidate/committed carrier subtype. Generic checks remain strict and the
layout is fail-closed for combinations outside this exact profile. Its focused
kernel persistence restart, trial rollback and competing-source rejection
checks pass; the broader supported forcing envelope still needs explicit
negative tests before bounded admission.
Do not weaken generic admission or reuse an unrelated layout. The physical
meaning of source terms and accepted water owners remains fixed. No tolerance
or solver-policy change is proposed.

Affected invariants: state ownership, trial/accept/reject isolation, restart
fidelity, exactly-once mass accounting and bounded capability admission.


## Local preservation checkpoint, 2026-10-06

The bounded three-owner route now passes O0/O2 trial, rollback, retry, replay,
kernel persistence restart, source-rate ownership and water-balance checks for
static and shrinking geometry. Ten additional fail-closed controls cover Snow,
soil temperature, Black, absent macropore or Boesten activation, drainage
response, elasticity, direct retention, competing generic top flux, and invalid
canopy cover. Each leaves committed state unchanged and publishes no candidate.
The earlier competing macropore source control remains in place.

Standalone Boesten/Black, bootstrap/common forcing, A10 rapid drainage,
MIGMAC09 and PERCH20 restart preservation pass, as does the Rutter source-window
O0/O2 identity gate. Boesten preservation uses an explicit mode that omits only
the original work-unit file-delta admission check; the original physics and
lifecycle assertions remain mandatory. Compile dependency lists were repaired
without changing tolerances or runtime physics.

Commands, checkpoint identities, raw compressed logs, hashes and markers are in
`tests/qualification/ppa-wu05-migmac10-local-20261006/evidence.json`.
These results supersede the earlier pending negative-control and preservation
statements for exactly this tested scope. They do not establish serialized FMR
restart-bundle equivalence, complete Andelst equivalence or production admission.

The current canonical head observed during recovery is `78acf56f931763d2e1d4924b3dea0742f231d2e8`.
Its shared-backend frost changes are not merged into this work-unit postimage.
Reconciliation and qualification of that merged postimage remain required.
The isolated continuation branch is `work/ppa-wu05-migmac10-envelope-preservation`.
GitHub publication was rejected by automatic approval review; evidence is
committed locally and remote persistence must not be claimed.
