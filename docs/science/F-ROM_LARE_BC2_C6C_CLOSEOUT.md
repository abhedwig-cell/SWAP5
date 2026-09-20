# F-ROM-LARE BC2-C6C BEMR mathematical qualification closeout

## Decision

**BEMR is mathematically qualified on the unchanged C5Z synthetic domain.**

C6C remains response-free. It does not execute a free-running Layer-ROM and does not change Reference Richards, RossFast or production groundwater coupling.

## Result

The authoritative exact-sharded run is GitHub Actions run `35523252423` at execution head `d956da43...`. All 168 preregistered B14 cases pass every frozen gate from all five starts, for 840 successful fixed-start solves in total.

The gates cover strict state/moment realizability, convergence, numerical branch agreement, bounded effective saturation, hydraulic pressure/flux continuity, storage and first-moment recovery, independent 96/192-point quadrature consistency, and the no-response firewall.

Sampled effective saturation across the complete authority stays between approximately 0.35345 and 0.97136, inside the frozen [0.02, 0.995] qualification interval.

## Relation to C5Z

C5Z failed because a polynomial written directly in water content overshot the upper admissible saturation bound in 14 of 168 cases.

C6C does not repair that polynomial. BEMR instead writes a cubic algebraic profile in the bounded entropy-dual coordinate and maps it to effective saturation through the fixed logistic inverse. Bounds are therefore structural for every finite coefficient vector. No clipping, narrower moment domain, relaxed constitutive interval, polynomial-order change or response-driven tuning was used.

The exact same C5Z partitions, mean-saturation profiles, moment patterns and HEAD_RISE/HEAD_FALL boundary cases were retained. All 168 also pass the stricter moment-realizability condition associated with the frozen BEMR interval.

## Numerical evidence

The authoritative sharded execution reports median Jacobian condition number about 4294.14 and maximum about 13507.0. Conditioning was prospectively diagnostic rather than a hard gate. It creates neither convergence failure nor branch ambiguity.

Worst hydraulic and state residuals remain far inside the preregistered physical gates. An independent serial execution, run `35522955216`, reproduces the same status, gates and 168/168 qualification counts. Small floating-point differences make the detailed JSON non-byte-identical but do not alter any scientific decision.

## What C6C does not establish

Mathematical admissibility is not hydrological fidelity.

C6C has not shown that BEMR improves interface flux relative to `CURRENT_LAYER_FACE`, has not executed the moment state dynamically, and has not established a free-running ROM, an application envelope or a speedup.

## Next authority

C6D is authorized as an exposed frozen-state mechanism discriminator.

It must project both storage and centered first water-content moment directly from immutable fine-Reference states, solve the already-qualified BEMR algebraic map offline, and compare resulting interface fluxes with the fine Reference and existing `CURRENT_LAYER_FACE` mechanism baseline.

BEMR candidate flux may not feed back into Reference execution. No moment localization or free-running implementation is authorized by C6C.
