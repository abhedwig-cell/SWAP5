# F-PE-SETUP02 closeout — scalable tile/ledger identity validation

Date: 2026-09-27

Status: `CLOSED_PARTIAL_GAIN_REGISTRY_SUCCESSOR`

PR:
`#678 — F-PE-SETUP02: scalable tile/ledger identity uniqueness validation`

## Decision

Scalable top-level tile/ledger uniqueness validation is semantically viable and reduces large-N bootstrap time, but it does not clear the frozen performance gates.

At N=40,000:
- baseline app initialize: ~3.93 s;
- candidate: ~2.61 s;
- speedup: ~1.50x.

The remaining dominant superlinear mechanism is the participant registry bind path, which repeats duplicate-tile and free-slot scans for every participant.

Select:

`F-PE-SETUP03 — prevalidated sequential registry-bind qualification`

SETUP03 must keep the generic registry behavior intact and expose any fast path only under explicit prevalidated bootstrap authority.

## Production boundary

No production `src/**` change in SETUP02.

## Closure

`CLOSED_PARTIAL_GAIN_REGISTRY_SUCCESSOR`
