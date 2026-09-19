# F-ROMV MDE Stage 1: B01 template-local closure pre-screen

**Status:** CLOSED EARLY NO-GO  
**Decision:** `STOP_SIMPLE_TEMPLATE_LOCAL_ROM`  
**Production ROM:** not authorized  
**Parent:** F-ROMV computational-value go/no exploration

## Purpose

F-ROMV allowed exactly one narrow experiment before any further ROM architecture work: test whether the already-qualified B01 material-specific state representation can support a simple conservative reduced dynamics law on held-out histories.

Stage 1 deliberately tests the scientific gate before spending effort on RossFast or spatially coarsened Richards performance comparators. A scientific early kill ends the current MDE.

## Frozen design

The data authority is the immutable ROM1AR2 artifact from workflow run `35379176697`, artifact `10561841507`, digest `sha256:2b04e188b7ce1593e073031fc43580550513e857dfb74b9993844a3230a1a67f`. The O0/O2 raw trajectory payload is bit-identical with SHA-256 `f1ea53496cd08cbadf1ceaad46c78d83a0767957fd9de676c88c51162346a1e0`.

Only B01 is used. D01-D08 provide 504 discovery transitions. H01-H04 provide 252 held-out transitions and are not used for fitting or model selection.

The previously frozen nine-dimensional `Z8_PLUS_G8` coordinate is reparameterized without information loss into explicit total storage, seven band contrasts and G8. Total storage is advanced from the exact imposed top exchange and the predicted bottom exchange:

`S_next = S_current - top_exchange - bottom_outward_exchange_predicted`.

This makes the water ledger structural. There is no correction flux added after the prediction.

The closure is the preregistered low-capacity bilinear controlled affine model fitted by SVD least squares. The OOD gate is also frozen: every state coordinate must remain inside the discovery min/max envelope and the exact forcing tuple must have occurred in discovery. Outside that domain, the hybrid route uses the recorded full-order transition.

## Result

The water-accounting part behaves as designed. The maximum structural mass residual of reduced hybrid steps remains below the `1e-12 cm` gate. This does **not** rescue the closure, because the hydrological dynamics fail independently.

The strongest held-out failure is H02. The full-order trajectory changes bottom-flux sign for the second time at step 57. The reduced hybrid trajectory changes sign at step 38, nineteen observation steps too early. The hybrid route produces nineteen bottom-flux sign mismatches in H02, even though those steps are classified as inside the frozen validity domain. The one-step diagnostic already shows wrong signs at steps 57, 58 and 59 from exact full-order starting states, so the failure is not only accumulated recursive drift.

H03 is more severe. Eight reduced transitions classified as in-domain reconstruct water contents outside the physical B01 interval. The first occurs at step 41 after switching to `BOTTOM_HEAD_FALL`. The corresponding predicted total-storage error is about `-1689 cm`, while the structural ledger still closes because the bottom-exchange prediction itself has become catastrophic. The frozen OOD detector therefore fails to protect against an important failure mode.

H04 demonstrates the opposite boundary: its combined forcing tuples were deliberately unseen in discovery, so the frozen gate routes all 63 steps to full-order fallback. That is scientifically safe, but provides no reduced-order value for that history.

Across all four held-out histories the hybrid route falls back on 78 of 252 steps, a fraction of about 0.310. More importantly, some of the remaining supposedly in-domain reduced steps are hydrologically wrong.

## Discovery identifiability diagnostic

The 40-column regression design is formally full rank, but its condition number is approximately `1.49e11`. Leave-one-discovery-history-out diagnostics are particularly poor for D07 and D08, including bottom-flux sign failures and, for D08, invalid reconstructed states.

This matters for interpretation. Regularization or a different OOD metric might numerically stabilize another model. But introducing them **after observing this result** would be post-result architecture and validity retuning. The Stage-1 preregistration explicitly forbids that.

The correct conclusion is therefore not that every conceivable ROM for Richards flow is impossible. It is narrower and more useful: the current F-ROMV hypothesis does not survive its preregistered simple-closure falsification, and this workstream has no authority to escalate to a more complex surrogate merely to obtain a positive result.

## Gate adjudication

The preregistered early-kill conditions resolve as follows:

| Gate | Result |
| --- | --- |
| structural water ledger | PASS |
| finite/physically admissible in-domain reduced state | **FAIL** |
| correct nonzero bottom-flux sign on in-domain hybrid steps | **FAIL** |
| held-out reversal timing within one 0.0008-day step | **FAIL** |
| fail-closed unseen combined forcing | PASS, H04 63/63 fallback |

Because the scientific gate fails, the RossFast and spatially coarsened Richards cost-error stage is not executed. Performance cannot make a hydrologically invalid closure acceptable.

## Decision

**STOP_SIMPLE_TEMPLATE_LOCAL_ROM.**

This closes the current F-ROMV minimal experiment negatively. It preserves the earlier ROM-1 finding that B01 has material-specific state-compression evidence, but shows that state separation alone is not enough to obtain a safe, useful low-capacity dynamics law.

No production ROM, ROM-2 closure programme, cross-material ROM, neural-operator escalation, post-result regularization tuning or post-result OOD retuning is authorized.

A future reopening would need a new independently governed proposition. It should first be justified by new evidence that a concrete MultiSWAP computational bottleneck remains after direct solver/runtime improvements, and it must retain this negative result rather than retuning it away.
