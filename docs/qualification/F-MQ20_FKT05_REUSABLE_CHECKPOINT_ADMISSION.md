# F-MQ20 — F-KT05 reusable checkpoint admission

F-MQ20 is qualification-only and starts from the qualified F-MQ19 head `f7cf39858ad3f8638574357dc5c59bd4b8651c34`.

## Admitted downstream evidence

F-KT05 is consumed from exact persisted qualification evidence only:

- status-promotion head: `f50b8cd20221fac27a2059b6c6192ed0b7384be8`;
- qualification-evidence commit: `6911549acbcb62ef8af9ae2d96d5b4f938daf1e2`;
- tested postimage: `f7d2ee5e81f1d6686c96114984239e97ba6a8a8a`;
- qualification run: `34125537033` (`success`);
- qualification blob: `95efe0016a35cce4989dfb68f021bef69c5af453`;
- tested F-KT05 gate blob: `8957180db3d0d6b650f09829e875e12faf819b52`.

The admitted contract provides an opaque reusable checkpoint containing a physical-state clone plus lineage, revision and time provenance. It contains no solver scratch or warm-start state, has no commit/rollback authority, and stale revision, cross-lineage or time mismatch fail before physical execution. Reusing the same current committed checkpoint is qualified, including replay from the same physical committed origin.

## F-MQ effect

This closes/strengthens production-kernel prerequisites for replay-related rows:

- R08: reusable replay/checkpoint prerequisite admitted;
- P05: reusable physical-state-clone checkpoint prerequisite admitted;
- P10: production-kernel reusable checkpoint prerequisite admitted;
- P11: same-committed-state replay prerequisite admitted.

No complete real-physics row is promoted. A reference-derived B1.10 event/checkpoint fixture and executable production reference route are still required for real P10/P11 qualification. P16/P17 remain blocked on complete unrounded SWAP interval mass accounting.

## Fail-closed context

F-SI06 is still unqualified on the observed head, F-VQ12 is `PENDING_FVQ12_CI`, and F-MR01 has only persisted ownership/admission contracts. None is consumed as F-MQ20 qualification evidence.

Coverage therefore remains 27/35 synthetic, 0/35 complete real physics and 0/35 production runtime.
