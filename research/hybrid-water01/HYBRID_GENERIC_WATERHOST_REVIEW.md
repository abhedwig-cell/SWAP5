# Generic hybrid waterhost: original Grassgrowth prototype

The former host fixed112 pressure values, the1998 Andelst clock and the
macro/Cauchy route. This block makes project identity, node count and calendar
explicit and gives each transaction its own allocatable pressure array. The
same existing host now executes original113-node Grassgrowth with prescribed
groundwater and no macro/snow, using original Fortran physics and inputs.
No general framework or physical process rewrite is introduced.

Actual successful source head: `91ef5ff08a49d6e874d5b54b878339cd268ccdb6`.
Canonical baseline: `01a9d29c380645dec880257f360174b5cb5ea5c0`.
All app/src/tools/tests/workflow dependencies remain identical to that tested
head; later changes only retain/audit evidence and document the result.
The owning selection is `integration/f-ci/HYBRID_GENERIC_WATERHOST_20261111.json`.

## Implemented behavior

- `state_t%pressure` owns its allocated grid. Clones do not alias; absent or
  foreign grids cannot produce a valid temporal comparison.
- The kernel accepts explicit per-column grid/epoch metadata and retains the
  legacy Andelst protocol. Each committed column owns its clock and revision.
  Original project water budgets remain fixed: Andelst1e-6cm, Grass1e-10cm.
- The nonmacro donor receipt reports absent macro contributions as zero without
  accessing unallocated macro arrays. The existing Andelst correction is refused
  for Grassgrowth; it is not relabeled as a generic boundary receipt.
- The new `S5NON004` auxiliary stream binds mode/grid/clock and retains old step
  and canopy stock. The native original restart retains the other physical/crop/
  thermal state. Original Andelst macro stream and corrective physics are unchanged.
- Schema3 durable publication is still acceptance-gated and binds project,
  original inputs and numerical build. Foreign/invalid inputs fail before
  publication. One refused column stays closed while another can advance.
- The public launcher has explicit `HYBRID_GRASSGROWTH_WATER`, capped at day4.
  Native Grassgrowth/Hupsel selection and the native1e-5C route remain available
  with their existing qualified scopes.

See [the explicit contract](HYBRID_GENERIC_WATERHOST_CONTRACT.md) and
`docs/science/HYBRID_GENERIC_WATERHOST.md` for commands and API meaning.

## Actual qualification

The original donor is O2. O0/O2 below describes the actual SWAP5 transaction
kernel and its cold real-owner state/clone tests, not a full original O0 donor.

| Original four-day case | Windows GNU16.2 max independent water residual | Ubuntu26/GNU15.2 max independent water residual |
| --- | ---: | ---: |
| Grassgrowth, kernelO0 | 1.71440553e-14cm | 1.86432900e-14cm |
| Grassgrowth, kernelO2 | 1.71440553e-14cm | 1.86432900e-14cm |
| Andelst, kernelO0 | 5.96535321e-7cm | 5.96535181e-7cm |
| Andelst, kernelO2 | 5.96535321e-7cm | 5.96535181e-7cm |

All cases have every original day1..4, finite stock/flow/pressure values and the
unchanged project water guard. OriginalGrass own2-to4 reproduces every physical
suffix record and both complete native/auxiliary payloads exactly. Distinct
boundary trajectories interleave exactly against separate controls. Injected
bad mass refuses a column, preserves its previous accepted state/clock and
leaves another column usable. Additional real-kernel protocol tests distinguish
the two budgets using the same5e-10cm defect and interleave different grids/
epochs. Unknown model/protocol, zero grid, nonfinite clock, foreign binding and
foreign nonmacro mode/grid/clock refuse. Public cold and fresh continuation are
exact to the qualified original controls. Public requests beyond4 days refuse
before creating output.

The actual [Ubuntu job](https://github.com/abhedwig-cell/SWAP5/actions/runs/43074284084/job/130709954635)
passes every selected step. Its original-source cold build does not launch a
full reference model. The actual frozen canonical Andelst control is compiled
on the same runner, and each corresponding complete cold/restored payload and
all physical prefix records match current source. Windows byte results are not
imported as Linux preservation. Unrelated jobs are explicitly skipped, not PASS.

## Retained failures and scientific limits

The first new assertion demanded cold/restored Andelst macro payload equality.
The actual old donor has the same96-byte difference in its15,322,608-byte
auxiliary file. Old/current corresponding cold payloads and corresponding
restored payloads are entirely byte-exact; native `result.end` and physical
suffix records are exact. We preserve that prior contract rather than claim
new cold/restored macro equality or classify unexplained bytes as harmless.
Both initial failed assertions, native data and distinguishing old controls
are retained. No tolerance or model repair was used.

An initial reuse adapter expected per-case RESULT.json. The actual producer
stores successful case events at root and complete committed rows in
daily.jsonl; those were checked directly. No producer report was manufactured
and passed native runs were not repeated. Two sparse-checkout preflights missed
a helper then the owning authority file; both ended before compilation/model
execution. Their complete logs remain with the successful job log. The final
owning checkout inventory passes. No skipped model test supplies a PASS.

Read-only comparison of eight unrounded authoritative water quantities for the
first4 days against the sealed original B0 has maximum observed difference
4.817e-13cm, within the printed reference precision. The original legacy CSV
has five decimal places and a different crop-output schema; its rounded text
is not a new5e-6cm physical acceptance tolerance. The descriptive comparison
is retained separately, without a new reference run or whole-science claim.

This is a4-day original water prototype and exact own state contract. It does
not qualify a full hybrid Grassgrowth project, the donor heat under native1e-5C,
complete energy or runtime parity. Day188/day584 and all earlier scientific
failures remain open. Existing full Grass/Andelst/Hupsel receipts are preserved
under their exact source/profile scopes.

## Reproduction and development return

The pinned original source ZIP is411215bytes, SHA256
`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
the existing original TTUTIL archive hash remains
`ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`.
Generated source, actual compiler commands, native executables, base objects,
library/module/input hashes, raw records and retained failures are in the proof.
Input bytes are checked against each platform's original versioned project;
no cross-platform binary restart is claimed.

| Retained capsule | Bytes | Members | SHA256 |
| --- | ---: | ---: | --- |
| `hybrid-generic-windows-20261111.tar.xz` | 8934280 | 1877 | `d33f4d1cb4ce380bcbbeae3a852415b80bb92fa7abeee73ceaf472d56dbac7af` |
| `hybrid-generic-linux-20261111.tar.xz` | 9610952 | 2674 | `728b357715301fcd39307829ce868913e105be56001514fb69b3883ae1fecacf` |

Independent extraction verifies all4551 members,818 source/build/input identity
checks, raw physical balances, same-platform baseline preservation, exact own
suffix/payloads, instance/refusal and public execution. Run without any model:

```sh
python -B research/hybrid-water01/audit_generic_hybrid_proof.py \
  --archive research/hybrid-water01/hybrid-generic-windows-20261111.tar.xz \
  --sha256 d33f4d1cb4ce380bcbbeae3a852415b80bb92fa7abeee73ceaf472d56dbac7af
python -B research/hybrid-water01/audit_generic_hybrid_proof.py \
  --archive research/hybrid-water01/hybrid-generic-linux-20261111.tar.xz \
  --sha256 728b357715301fcd39307829ce868913e105be56001514fb69b3883ae1fecacf
```

Actual Linux native-case event totals are0.48/0.44seconds for Grass and5.03/
5.04seconds for Andelst (kernelO0/O2), including the selected controls. Build,
link and validation durations are recorded separately where available. Initial
Windows combined/public stages have no separate pure-native timing: UNKNOWN.
No full trajectory was repeated. These timings are not an accuracy-matched
comparison with the native thermal route.

Functional coverage gains a second original grid/boundary configuration in the
same existing hybrid host, bounded to4 days. The count of completely qualified
historical projects does not increase. Reliability gains explicit variable-grid
ownership, exact Grass restart and cross-platform owning controls while preserving
Andelst. Development return is a coherent source implementation plus short actual
original-input controls, not another long performance/reference campaign.
