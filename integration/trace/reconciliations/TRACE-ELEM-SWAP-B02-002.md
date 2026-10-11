# TRACE-ELEM-SWAP-B02-002 reconciliation

Date closed: 2026-09-19
Prospective result: `NO_CONFIRMED_DISCREPANCY`
Candidate IDs: none

## Element

Water-balance sign, unit and transfer-accounting semantics, selected before detailed inspection as the Batch-02 transfer/accounting relation.

## Reviewer-facing scientific contract

`docs/science/water-balance-and-conventions.md` distinguishes three different semantics that must not be collapsed:

1. the bounded Richards hydraulic convention, with upward-positive `z` and hydraulic `q`;
2. process-local sink magnitudes, such as nonnegative root extraction;
3. VQ normalized accounting, with positive signed amount into the accounting domain and negative signed amount out.

It also states the normalized accepted-interval conservation identity:

`delta_storage = storage_end - storage_start`

`net_external = sum(external signed amounts)`

`residual = delta_storage - net_external`.

Rates are not booked as amounts until integrated over their applicable accepted interval.

## Documentation and normalization authority

F-DOC21 explicitly qualifies this bounded claim surface.

Its authority matrix requires:

- separation of process-local hydraulic signs from normalized verification signs;
- storage change versus net external transfer as the accounting identity;
- explicit adapter translation where implementation-local signs differ;
- no universal raw-code sign convention inferred from names;
- no universal mass tolerance invented by prose.

The VQ mass-accounting contract independently defines the same normalized sign convention and hard residual. It requires unrounded interval amounts, stable term identities, explicit accounting scope and recomputation of the residual rather than trusting a production-reported diagnostic.

## Transaction ownership and exactly-once booking

The same VQ contract distinguishes trial and committed accounting:

- trial amounts may exist for diagnosis;
- rejected trials do not alter committed storage or committed totals;
- exactly one accepted trial contributes committed accounting;
- retry history cannot duplicate physical transfers.

F-TB11 permanent-preservation authority independently records PASS for:

- mass-accounting fail-closed behaviour;
- transaction acceptance fail-closed behaviour;
- rejected-publication immutability;
- restart continuation;
- non-waivable horizontal mass conservation.

This matches the reviewer statement that a numerically computed flux is not automatically an authoritative model transfer; authority follows acceptance and commit.

## Internal and coupled transfers

The reviewer page and VQ contract agree that transfers between stores inside one accounting domain are internal and cancel from the external balance.

For coupled components, the same physical exchange is external to each component but internal to the combined system. The VQ contract separately requires component-local balance, interface-pair balance and system balance after internal cancellation.

No head-convergence condition is treated as a substitute for water-transfer conservation.

## Units and amount basis

The reviewer page states that process modules often expose rates, whereas mass verification uses accepted-interval amounts. The preferred normalized column basis is water-equivalent depth over column area.

The VQ contract independently requires one unambiguous amount/unit basis per record and permits a volume basis only when sufficient area/basis metadata is retained.

## Post-selection canonical delta

After the preceding Batch-02 E01 closeout, canonical advanced from `b70abdaa8e73f6963dd6b535b482ebbf06b02d89` to `5a6af72aed06025a1c7f7ffeb21a968a497b5470`.

The intervening files are governance, moving-preservation and publication-test surfaces for lower-boundary, Ross and coupling work. They do not modify:

- `docs/science/water-balance-and-conventions.md`;
- `docs/verification/mass-accounting-contract.md`;
- the F-DOC21 water-balance authority;
- the F-TB11 permanent mass/transaction authority;
- production water-accounting semantics selected by this element.

## TRACE disposition

No prospectively new theory-documentation-implementation-evidence conflict was identified.

No candidate was registered.

This denominator null result is deliberately bounded. It does not assert one universal sign convention for all raw variables, one universal active-storage topology, or one universal mass tolerance.
