# Candidate forcing-event temporal continuation

## Prescribed-root successor design (2026-09-24)

Third-period diagnostic successor: copy only owned solver inputs/history at the
last native-converged callback in the failed unmarked period. Rebind prescribed
roots separately from zero embedded roots; sweep raw and absolute-clock-grid
durations without changing committed state. A separate `Atm02Dense` candidate
uses existing retry_scale=0.9/max_retries=128 from the original third-period
restart boundary, same forcing/duration/tolerances/history, no event reseeding.
It must complete twice with exact full-state restart replay and accepted uptake
before claiming completion. The prior 0.8/64 rejection stays in the test.
Neither diagnostic feasibility nor this preregistration establishes success.

Component qualification at 46982aee045a84e9613ff152997c5526477ab281:
`tests/fsi/run_ppa_free_drainage_indicator.ps1` passes O0/O2 with identical
transcripts (build `swap-free-drainage-1bf65088-cde8-41c1-a946-87134e07ee7e`).
All 45 cases compare the root-enabled derivative with an independent flux/source
oracle and the no-root delta. Eight atomic rejection cases cover unbound vector,
wrong count/shape, negative, NaN, oversized, unsupported extension and duplicate
embedded roots. Existing mode-2 FSI38 and mode-5 FSI25 preservation passes.
The initial duplicate-root fixture incorrectly invoked a rejecting binding API;
46982aee0 fixes the fixture by corrupting its target only after valid binding.
Runtime successor at d234a4524 passes the bounded Atm02Events O0/O2 gate:
3,840,522 identical lines, SHA256
`8C9980AE4862BAC6957E302881EABB385FC911A17C0A8A0FD051AEE214BF4585`.
Original then changed-weather half-days complete with exact owner/restart and
root amounts; unbound-service, failed/partial attempts and restored replay
preserve committed state and accepted-only publication. The third unmarked
half-day still fails after 7351 internal accepts and rolls back exactly: this
is not third-period completion. Root-inactive Windows and canonical output
preservation pass. Full evidence and remaining scope are recorded in
`PPA_ATM02_PRODUCTION_COMPOSITION_PREREGISTRATION.json`.

Baseline: 543955b9a. Bounded implementation is authorized first in the read-only
derivative component, then in runtime forwarding only after direct oracle/guard
qualification. Accept exactly `b110_root_sink_provider_t`, not extensions or
other root policies. Its node count and associated vector must match geometry;
all entries must be finite, nonnegative and at most 1e6 cm/day. Preserve the
existing requirement that the source/sink provider's embedded root vector is
zero, preventing double subtraction. Add the prescribed vector once to the
physical sink in the existing C*dz divergence formula. No derivative of a
head-dependent or stateful root response is introduced.

Unbound, wrong-sized, negative, nonfinite, oversized and duplicate-root inputs
remain atomically unavailable with all-zero output. No-root behavior, physical
state, accepted-only history, mass ledger, tolerances and default-false events
remain unchanged. The backend's root-event rejection stays in place during
component qualification. Runtime widening subsequently requires changed-weather
owner/restart, failed/partial rollback, root amount accounting, and root-inactive
preservation gates. This design is not itself runtime qualification or admission.

Baseline: ea8354e6a. Status: explicit runtime event forwarding implemented at
61e244883, bounded Windows and rollback qualification at 69ea158d1; not canonically admitted.
Derivative component: candidate module at 235a71d03. The component deliberately restricts the numerical envelope
further: head >= -1e4 cm, alpha in [1e-8,1], n in (1,3], m >= 0.1,
lambda in [0,1], Ksat <= 1e6, and finite bounded geometry/source rates.
It requires initialized standard MvG coefficients and exact committed-water
consistency through the existing storage-binding guard. These are candidate
availability bounds, not restrictions added to the default physical model.
Provider duration must also be finite and positive before provider evaluation;
all unavailable results return an all-zero derivative atomically.
Owning workstream: PPA free-drainage temporal continuation / WU04C windows.
Evidence: PPA_MVG_STORAGE_DIFFERENCE_STATUS.json, WindowRejection gate.

## Diagnosed boundary

The existing certificate uses `0.5*dt*(current_derivative-previous_derivative)`.
Across a declared discontinuity, the saved derivative belongs to the previous
forcing. Refinement can demand steps below the native solve's useful precision
range. A test-only diagnostic evaluates the same converged solution using the
right-limit derivative at the unchanged accepted state under the new forcing.
This is not permission to reset history opportunistically after rejection.

For the bounded mode-7, fixed-flux, arithmetic-face, explicit-conductivity profile:

```
q(1) = prescribed top flux
q(j) = -0.5*(K(j-1)+K(j))*((h(j-1)-h(j))/distance(j)+1)
q(n+1) = -K(n)
dhdt(j) = (q(j+1)-q(j)+source(j)-sink(j))/(C(j)*dz(j))
```

Evaluate K and C from the bound constitutive provider at the committed heads.
No head, water content, flux, residual, mass ledger or tolerance is changed.

## Explicit implementation boundary

1. Append a default-false, time-stamped forcing-event marker to the typed runtime
   forcing and a default-false event indication to the temporal-indicator request.
   The marker declares an input discontinuity, not a looser numerical tolerance.
2. Preparation must reject nonfinite or mismatched event times and unsupported
   profiles. An event is admitted only at the requested outer interval start,
   with the explicit free-drainage temporal service and history-carrying state.
3. The backend forwards event indication only for a trial starting exactly at
   that declared boundary. Retries there recompute the same right-limit
   derivative from their unchanged base. Later accepted substeps use normal
   committed history. No hidden detection from a large error or solver failure.
4. Compute the event derivative in call-local scratch. Substitute it only in
   the certificate's previous-derivative input. Existing accepted-only temporal
   history publication remains authoritative. Never overwrite committed history
   before a successful transaction; no second persistent state owner or event
   consumption ledger is needed for this exact-time bounded protocol.
5. Initial envelope: standard bound MvG, fixed-flux top, bottom mode 7,
   conductivity mean 1, explicit conductivity, no dynamic root uptake,
   macropores, snow, evaporation-state processes or drainage-response process.
   Validate shapes, finite values, positive capacity/geometry and compatible
   provider types before evaluation. Unsupported event requests fail closed;
   default-false requests retain the existing certificate path exactly.

## Required qualification before a success claim

- Independent derivative comparison against the existing test oracle; shape,
  provider, geometry, nonfinite and unsupported-profile guards.
- Windows success gate with the same two forcing amplitudes, original hard mass
  and temporal budgets, independent source identities and physical cm amounts.
- Full continued/restored state, temporal-history and provenance identity.
- A declared event followed by failed and partially accepted outer attempts:
  no external state/history/source publication; replay reconstructs equivalently.
- Wrong event time and missing temporal-service admission guards; reused backend
  clears event configuration. Event is not repeatedly applied after first accept.
- Default WindowRejection gate remains unchanged when the marker is absent;
  mode-2/5 and default application preservation gates stay green.

Affected invariants: 3, 7, 9, 13, 23, 25. This design changes no scientific
forcing amplitude, restart payload or canonical admission boundary. Disk restart,
arbitrary within-window forcing, and dynamic top-regime switching remain outside
this bounded implementation. Local checkpoint qualification is not migration
closure.

## Bounded implementation evidence

At 69ea158d1, Windows passes O0/O2 with all 300241 transcript lines identical.
Both new half-day windows are composed from owner-issued committed-top snapshots;
the second changes rain/irrigation from 0.20/0.10 to 0.16/0.08 cm/day. The
explicit marker is set only for that second window. Continued and restored runs
have identical full physical state, temporal history and provenance. Each source
amount is published once. Hard mass and temporal budgets are unchanged.

Wrong and nonfinite event times leave the owner unchanged. An unbound event
service rejects before HeadCalc. Zero-retry failure and failure after one internal
accepted substep roll back completely; explicitly rebound restored replay equals
the uninterrupted result and consumes source progress once. The generic reference
indicator rejects event requests explicitly; it cannot silently ignore the marker.

The unmarked WindowRejection gate retains the exact pre-integration transcript
hash E4B98E0F37967776725844E67A47AC5822F234FA656D93E5BBB09F3034031280 at O0/O2.
Mode-2/5 indicator preservation passes at d6371fcfe (its dependency surface is
unchanged by the subsequent backend-only envelope guard). CanonicalOutput passes
again at 69ea158d1. Build paths and hashes are recorded in the storage status file.

This qualifies the specified two-window in-memory continuation, not arbitrary
event trains, disk restart, all top regimes, or other interception options.
