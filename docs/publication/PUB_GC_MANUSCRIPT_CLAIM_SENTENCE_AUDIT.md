# PUB-GC manuscript claim-to-sentence audit

## Purpose

This audit checks the consolidated manuscript against `PUB_GC_COUPLE_CLAIM_EVIDENCE_LEDGER.md`. It is not a second claim ledger. Its purpose is to ensure that manuscript wording does not imply a stronger evidence state than the governed claim.

## Central claim audit

| Claim | Manuscript location | Wording/evidence check | Disposition |
| --- | --- | --- | --- |
| GC-C01 independent solver/state ownership | 1.5, 2.1, 5.3 | Described as coupling contract, not novelty by itself; evidence remains bounded | PASS_RESTRICTED |
| GC-C02 immutable accepted SWAP origin | 2.5, 3.2, 4.2 | Replayed trials are explicitly alternative candidates from one origin | PASS_RESTRICTED |
| GC-C03 MODFLOW prepared solve with SWAP replay | 2.7–2.9, 4.1, 4.3 | Method states asymmetric internal iteration semantics without claiming MODFLOW rollback | PASS_RESTRICTED |
| GC-C04 dual coupled convergence | 2.9, 3.3, 4.3, 5.4 | Numerical interface criterion is separated from hydrological relevance | PASS_RESTRICTED |
| GC-C05 distinct `q_bot`, `q_u`, `V_u` | 2.4, 4.1, 5.2, 6 | Manuscript explicitly rejects aliasing and reports the real E1 difference | PASS_RESTRICTED |
| GC-C06 rejected trials publish zero authoritative mass | 2.5, 2.10–2.12, 4.2 | Trial computation and publication authority remain distinct | PASS_RESTRICTED |
| GC-C07 exactly-once accepted publication | 2.11–2.12, 4.2, 6 | Ordered publication is described as qualified transaction; post-publication durability is excluded | PASS_RESTRICTED |
| GC-C08 response exposure without internal Richards Jacobian | 2.6, 4.4, 5.6 | Response is optional component information; no ownership transfer of solver internals is implied | PASS_RESTRICTED |
| GC-C09 physical identity of response | 2.4.3, 3.4, 4.4, 5.6 | `u_A` is named flux-driven predictor response, not universal head-to-exchange Jacobian | PASS_RESTRICTED |
| GC-C10 incremental value of supplied response | 3.5, 4.5, 5.6 | Manuscript reports modest value and explicitly closes standalone ACCELERATE implication | PASS_RESTRICTED |
| GC-C11 weak-coupling regime | 3.3, 4.3, 4.6, 5.4–5.5 | Weak physical effect is a result, not generalized to all applications | PASS_RESTRICTED |
| GC-C12 N:1 affine response reduction | 2.13, 3.8 | Kept as numerical composition rule; physical aggregation validity explicitly excluded | PASS_ARCHITECTURE_ONLY |
| GC-C13 regional scaling | 3.8, 4.7, 5.8, 6 | Manuscript explicitly states quantitative scaling is not established | PASS_NOT_CLAIMED |
| GC-C14 transferability beyond SWAP5 | 5.8 | Only principles are proposed; benefit in another model pair remains an empirical question | PASS_HYPOTHESIS_BOUNDED |
| GC-C15 realistic component-domain limit | 3.7, 4.7, 5.7–5.8, 6 | E7 states that authentic selected Hupsel drainage cannot be represented by the current production prescribed-head participant; zero coupled windows are reported explicitly and not misclassified as divergence | PASS_RESTRICTED |

## Abstract audit

- Interface/state/mass claims are supported by E1/E2.
- Two-to-five outer iterations and nanometre-scale head correction are supported by E3/E3-R.
- Response identity and 8.1% separation are supported by E4.
- `16 of 18` one-evaluation oracle advantage and no convergence-domain extension are supported by E5.
- E6 is described only as two negative component-envelope stress routes.
- E7 is described as a preregistered realistic component-domain limit: both frozen Hupsel days require drainage, the production prescribed-head owner rejects active drainage before owner allocation, and no loose/strong Hupsel correction is claimed.

## Known submission caveats

1. RQ5 is answered only in the bounded negative sense of a realistic component-domain limit; no realistic loose/strong correction magnitude is available.
2. The manuscript must not change `realistic application` into `validation`; the fallback conceptual MODFLOW fixture was never exercised for E7 because SWAP participant admission failed first.
3. Regional scalability remains outside the empirical result set unless E8 is separately executed.
4. Post-publication crash durability/restart is not proven by E2 and must remain distinct from pre-publication rollback safety.
5. The references section should be normalized to the selected journal style and externally rechecked before submission.

## Verdict

**NO_CURRENT_CLAIM_LEDGER_OVERRUN DETECTED.**

The manuscript is evidence-consistent through E7. No preregistered primary scientific gap remains for the current bounded coupling-contract framing; E7 closes negatively at the production component domain.
