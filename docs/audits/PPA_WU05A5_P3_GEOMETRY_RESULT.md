# PPA-WU05-A5 P3 local multi-domain geometry result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / MULTI_DOMAIN_GEOMETRY_CONTRACT_SUPPORTED`

## Exact source authority

Exact B1.11 `MPVOLUME`, `macropore.f90:1691+`.

The source sequence is:

1. calculate dynamic crack volume `VlMpDyCp` from matrix moisture/shrinkage history;
2. calculate total compartment macropore volume:
   `VlMpCp = VlMpDyCp + VlMpStCp`;
3. determine actual bottom of the main/deepest domain from the deepest compartment with qualifying macropore volume;
4. constrain that bottom by the potential depth required by the next domain;
5. derive every other domain bottom as:
   `ICpBtDm(id) = min(ICpBtDmPot(id), ICpBtDm(1))`;
6. partition compartment volume into domains using immutable `PpDmCp`:
   `VlMpDmCp(id,ic) = PpDmCp(id,ic) * VlMpCp(ic)`.

## Important geometry interpretation

`ICpBtDm` is not an independent physical degree of freedom.

It is an **accepted continuation representation of a derived geometry boundary** whose next candidate value is recomputed from:

- dynamic crack history;
- static macropore volume;
- immutable potential-domain geometry.

This explains why A1 correctly required it in atomic rollback even though A3 classified the geometry relation itself as recomputable.

## Source-consistent PpDmCp requirement

A local three-domain/five-compartment harness initially exposed an important condition:

domain proportions must already encode the shortening of shallower domains.

For example, below the potential bottom of domain 3 its `PpDmCp` is zero, and the remaining active domain proportions sum to one.

With source-consistent `PpDmCp`:

`sum_id VlMpDmCp(id,ic) = VlMpDyCp(ic) + VlMpStCp(ic)`

for every active compartment to machine precision.

No geometric volume is created or lost by domain partition.

## Dynamic-bottom experiment

Three dynamic-crack states were tested.

### No deep dynamic crack

Actual bottoms:

`[3, 3, 2]` (zero-based local harness indexing).

### Dynamic crack active to deepest compartment

Actual bottoms:

`[4, 3, 2]`.

Only the main/deepest domain extends to the new deepest active crack compartment. Shallower domains remain limited by their immutable potential bottoms.

### Deep crack closes again

Actual bottoms return to:

`[3, 3, 2]`.

Thus domain-bottom motion is a deterministic consequence of current/recomputed geometry.

## State-surface implication

The existing seven-field continuation state remains consistent with P3:

- `VlMpDyCp` carries hysteretic crack history;
- `VlMpDmCp` carries accepted per-domain compartment volume needed for atomic rollback/retry;
- `ICpBtDm` carries the accepted active-domain boundary needed for exact continuation/rollback;
- `PpDmCp`, `VlMpStCp`, and `ICpBtDmPot` remain immutable configuration/derived authority.

No new continuation field is required by this geometry experiment.

## H3/H4 disposition

- H3 seven-field continuation sufficiency: **supported by first multi-domain geometry falsification**.
- H4 derived geometry regeneration: **supported**.

Not yet fully qualified because water storage, exchange and drainage have not yet been composed over the same multi-domain geometry.

## Next step

Build P4 distributed matrix/macropore exchange over the active domain/compartment geometry and prove:

1. per-node/domain exchange ownership;
2. full-column internal cancellation;
3. compatibility with moving `ICpBtDm`;
4. no additional continuation field is required.
