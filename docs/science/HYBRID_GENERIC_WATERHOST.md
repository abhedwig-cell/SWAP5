# Explicit project state in the hybrid waterhost

The existing hybrid day host now supports an explicit original-project grid and
calendar, with per-instance pressure storage. Its qualified prototype adds the
original113-node Grassgrowth water configuration through the same host used by
112-node Andelst. The exact source/build/acceptance authority is
`integration/f-ci/HYBRID_GENERIC_WATERHOST_20261111.json`.

This is a bounded water-application extension. It neither replaces the native
Grassgrowth thermal route nor qualifies the donor heat trajectory under its
registered1e-5C temporal budget. Original full project and scientific receipts
retain their exact original source/profile scopes.

## State and acceptance contract

Pressure is an owned allocatable transaction-state component. Cloning preserves
values and shape without aliasing. Explicit protocol columns carry their grid
and epoch; committed clocks and revisions remain owned by the existing kernel.
The legacy Andelst protocol and112-node/35795 defaults remain supported. Unknown
models/protocols, invalid grids, nonfinite clocks/state and foreign checkpoint
bindings fail before acceptance or publication. A refused column cannot advance
again while another independent column remains usable.

| Explicit water model | Original configuration | Current bounded acceptance |
| --- | --- | --- |
| `HYBRID_ANDELST_WATER` | 112 nodes, macro/Cauchy, original1998 clock | Existing1e-6cm day guard; same-platform canonical four-day records and cold/restored payloads preserved |
| `HYBRID_GRASSGROWTH_WATER` | 113 nodes, no macro/snow, prescribed groundwater, original1980 clock | First4 days,1e-10cm day guard; own2-to4 physical records and both native/auxiliary payloads exact |

Original Fortran physics and original project inputs are retained. The macro
retry correction is rejected for the nonmacro prototype; absent macro stocks
are explicit zero contributions without touching unallocated legacy arrays.
The nonmacro auxiliary stream binds mode, node count and clock and restores the
old step and canopy stock. The existing macro stream is unchanged.

The existing schema3 durable publisher still publishes only after kernel
acceptance and binds project, original inputs and numerical source/build.
The new prototype has an explicit public four-day cap. Independent native
Grassgrowth and Hupsel model selection remains unchanged.

## Qualification and limits

Windows and Ubuntu26.04 actual kernelO0/O2 tests use the original O2 donor.
Cold real-owner shape/deep-clone and actual protocol tests cover different grids
and clocks, separate project mass limits, and negative framing. Original-input
four-day runs, exact own continuations, distinct physical boundary trajectories,
refusal isolation and foreign/malformed restart controls pass. Public cold and
fresh-process continuation commands also pass. Linux Andelst is compared against
actual canonical controls built on that same runner, not Windows byte results.

The initial stronger Andelst assertion exposed an existing96-byte difference
between cold and restored macro auxiliary files. The old donor has the same
difference; corresponding old/new cold files and corresponding old/new restored
files match entirely. Native `result.end` and physical suffix records are exact.
This preserves the old contract; it does not newly qualify cold/restored macro
byte equality. The failed assertions and both controls are retained.

See the [review and raw proof](https://github.com/abhedwig-cell/SWAP5/blob/integration/f-ci-canonical/research/hybrid-water01/HYBRID_GENERIC_WATERHOST_REVIEW.md)
for identities, measured costs, independent archive verification and the
unchanged scientific limits. Neither full Grassgrowth hybrid execution, full
heat qualification nor scientific equivalence is established by these4 days.
Day188/day584 and the complete-energy/runtime-parity limits remain open.

## Public bounded prototype

With an already prepared original distribution, the same public launcher uses:

```sh
python tools/solute/run_water.py --model HYBRID_GRASSGROWTH_WATER \
  --reference-work ./original-work --output ./grass-water-four \
  --days 4 --checkpoint-at 2
python tools/solute/run_water.py --model HYBRID_GRASSGROWTH_WATER \
  --reference-work ./original-work --output ./grass-water-resumed \
  --days 4 --restart ./grass-water-four/accepted-column-1-day-2.zip \
  --restart-day 2 --checkpoint-at 4
```

Requests beyond day4 refuse. Full native thermal execution continues to use
`NATIVE_GRASSGROWTH_WATER` with its own verified build and immutable profile.
