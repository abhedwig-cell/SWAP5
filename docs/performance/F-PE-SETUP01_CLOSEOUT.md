# F-PE-SETUP01 closeout — large-N groundwater setup decomposition

Date: 2026-09-27

Status: `CLOSED_SELECT_SCALABLE_ID_VALIDATION`

PR:
`#677 — F-PE-SETUP01: large-N groundwater setup decomposition`

## Decision

Recurring groundwater context materialization is too small to justify a dedicated optimization line:
- N=10,000: about 0.010 s;
- N=40,000: about 0.051 s.

The dominant large-N setup cost is one-time `app%initialize`:
- N=10,000: about 0.189 s;
- N=40,000: about 4.707 s.

Two O(N^2) prefix-scan uniqueness checks for `tile_id` and `ledger_id` are a concrete scaling defect consistent with that growth.

Select:
`F-PE-SETUP02 — scalable tile/ledger identity uniqueness validation`.

No production `src/**` change is included in SETUP01.

## Closure

`CLOSED_SELECT_SCALABLE_ID_VALIDATION`
