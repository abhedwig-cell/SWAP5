# PPA-WU05-MIGMAC01 result — covering-layer standard macropore route

Date: 2026-10-01

Status: `QUALIFIED_TRANSACTION_COMPOSITION_ACTIVE_E2E_PENDING`

Qualified postimage:
`f88c1fc3106b88fec60edb93fdc56f331ad75dff`

Qualification run:
`36925950836` — SUCCESS.

## Qualified

- source-faithful B1.11 covered-top potential operator;
- analytic covered-source Jacobian;
- trial-local evaluation from current Richards head at `IcTopMp-1`;
- covered route does not reuse A9 external rain/irrigation/melt/lateral ownership;
- accepted covered transfer is staged into macropore candidate only after solve acceptance;
- internal exchange bookkeeping includes the equal-and-opposite matrix sink;
- existing PERCH20 transaction composition preserved;
- PERCH20 reject/discard/replay/restart lifecycle preserved.

## Not yet claimed

This result is not yet production admission.

A dedicated active `IcTopMp > 1` end-to-end fixture must still demonstrate a positive covered
transfer with:

- converged Reference Richards;
- nonzero matrix loss at `top_node-1`;
- equal macropore storage gain;
- internal-exchange and whole-column mass closure;
- accepted-state immutability before commit;
- replay/restart identity.

No tolerance relaxation or direct-surface shortcut is permitted.
