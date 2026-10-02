# PPA-WU05-MIGMAC01 result — covering-layer standard macropore route

Date: 2026-10-02

Status: `QUALIFIED_PREREQUISITE_SOURCE_ORIGIN_COMPOSITION_BLOCKED`

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


## Active fixture falsification

Run `36932614330` reached and converged Reference Richards after the covered-route ownership
repair. The synthetic fixture started the covering cell at `h(2)=+0.25 cm`, but the accepted
Richards state was:

`h(2) = -66.629577345080222 cm`.

Consequently the exact B1.11 condition `h(IcTopMp-1) > 0` was false at acceptance and the
covered transfer was exactly zero. This is not a covering-operator failure. It falsifies this
synthetic state as an active covering-layer authority fixture.

Per the preregistered no-tuning rule, MIGMAC01 will not increase the synthetic starting head,
forcing, timestep or tolerances merely to obtain a positive transfer. The remaining admission
blocker is now a source-backed SWAP 4.3.1 state/interval with `IcTopMp>1` and positive accepted
covering-cell head.

## Source-backed recovery and current blocker (2026-10-02)

The missing source event is resolved by the preregistered modified-Andelst
experiment: accepted h(2)=+0.09997836 cm, covered transfer=6.05432484e-5 cm,
exact matrix sink ownership, macro closure=2.10e-16 cm.
The current source-origin Reference-Richards replay fails the complete strict
convergence gate and its last tentative covering head is negative.
Other exchange differs materially from B1.11; immutable serialized covering
parameters and an explicit matrix-area carrier are also absent.
See [source-origin replay result](PPA_WU05_MIGMAC01_SOURCE_ORIGIN_REPLAY_RESULT.md)
and [controlled reference result](PPA_WU05_MIGMAC01_CONTROLLED_REFERENCE_RESULT.md).
These replace the prior missing-source-event blocker; no active E2E qualification,
new preservation, production admission or closeout is claimed.
