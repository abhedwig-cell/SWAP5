# Candidate forcing-event temporal continuation

Baseline: ea8354e6a. Status: derivative component implemented; runtime event
forwarding remains a design, not implemented or admitted.
Derivative component: candidate module at 235a71d03; runtime event forwarding is
still unimplemented. The component deliberately restricts the numerical envelope
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
