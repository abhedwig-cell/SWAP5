# PPA-WU05-MIGMAC01 result — covering-layer standard macropore route

Date: 2026-10-02

Status: `QUALIFIED_PREREQUISITES_CORRECTED_SOURCE_REPLAY_BLOCKED`

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

## Reference discrepancy attributed (2026-10-02)

Exact last-MACRORATE diagnostics now confirm B1.11 starts perched detection
inside ordinary groundwater node 55, misses shallow saturated water and
counts ordinary node 55 twice. On identical source last-rate h/theta,
SWAP5 has main top 55 and perched top 1 / bottom 29. Diagnostic ablation
isolates the duplicate with an exact 2:1 node-55 rate ratio; it is not a
production change or admission fixture. The reference must be corrected and
qualified in B1 before whole-case comparison can qualify MIGMAC01.
PERCH21 must not be regressed to recreate this demonstrated defect.
See [reference carrier defect](PPA_WU05_MIGMAC01_REFERENCE_CARRIER_DEFECT.md).

## Corrected-reference recovery, 2026-10-02

Bounded B1 CALCGWL correction is targeted-qualified on head
5b4666d1a168b8f73868bfab0d00c8f342ce4fa8, run 36970592651 SUCCESS.
See PPA_WU05_MIGMAC01_B1_CORRECTION_RESULT.md for the exact scope.
Immutable B1.11 and the previous negative source replay remain preserved as
historical evidence; no global B1 successor admission is claimed.

A new first accepted positive-covered event was captured under the same fixed
modified-Andelst input: h(2)=0.00068230903875077459 cm,
covered=9.521088298971577e-7 cm, exact opposite matrix sink, macro residual
2.0801435118671108e-16 cm. This is corrected-source evidence.

SWAP5 ordinary and active macro replays on exact diagnostic postimage
44baf4a509d9238b7ac9cf16df8d49412b222e3c both request retry, reproduced O0/O2.
No accepted SWAP5 covered transfer is available. Strict native-rate precision,
remaining rate discrepancy, explicit matrix-area ownership and serialized
covering physical-parameter propagation remain blockers.
Full MIGMAC01 qualification, preservation, admission and closeout remain FALSE.
Canonical checked at 7a629a10cabb3553ff77474423e6ccac81b29aec; no affected production delta.
