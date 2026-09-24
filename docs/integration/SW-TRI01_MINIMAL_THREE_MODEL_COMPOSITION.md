# SW-TRI01 minimal real three-model composition

**Date:** 2026-09-24  
**Canonical base:** `879945f9b994db91bca2cacd1cb85ff381f45f39`  
**Status:** research composition / no production admission

## Goal

Compose the already admitted SWAP5-MODFLOW6 and SWAP5-Ribasim boundaries into one minimal three-model coupling without creating a second SWAP state owner or two incompatible SWAP candidates.

## Reconciliation finding

The current production participants cannot simply be invoked side by side.

The groundwater participant is admitted for a prescribed groundwater head with `bottom_mode=5`. The F-APP09 Ribasim surface-water participant is admitted for `bottom_mode=7`. More importantly, each participant owns a complete trial candidate from the accepted SWAP origin. Two full candidates from the same origin cannot be merged into one physically authoritative SWAP state.

The triangle therefore requires one SWAP trial containing both external boundary conditions.

The underlying typed forcing already has both carriers:

- `bottom_head` for the MODFLOW-controlled lower boundary;
- `drainage_response_controls` for the Ribasim-owned surface-water level.

The existing groundwater materializer copies a complete base forcing and changes only `bottom_head`. This gives a source-derived candidate composition order:

```text
accepted SWAP origin
    -> base physical forcing
    -> materialize Ribasim surface-water head
    -> use result as groundwater-materializer base
    -> materialize MODFLOW interface head
    -> one SWAP backend trial
    -> one candidate containing both responses
```

## TRI01-A

TRI01-A tests only that joint candidate boundary. No live external model is needed yet.

A PASS is prerequisite for any real three-model driver. A FAIL means the present production profiles are not composable and must be repaired at the forcing/candidate boundary rather than orchestrated around.

## Future gates

After TRI01-A:

1. TRI01-B: joint transaction participant with one origin, one candidate, dual receipt preflight and one SWAP commit.
2. TRI01-C: deterministic two-external-oracle orchestration proving retry/recomposition ordering.
3. TRI01-D: live MODFLOW6 plus real Ribasim in one coupling window.
4. TRI01-E: independent qualification and bounded production admission.

The publication rule must remain: no irreversible MODFLOW publication before the final Ribasim receipt and SWAP publication preflight are both satisfied.
