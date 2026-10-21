# MC-SOL01 dynamic accepted-temperature decay

## Proposed bounded nonlinear successor (not admitted)

MC-SOL01-DYNAMIC-DECAY02 starts at canonical `fcfdd3ae6bb2c9516c6e303b7aa112e418e04b3d`.
It widens only the thermal composition's sorption guard to the existing matrix
constructor domain, Freundlich exponent 0.5..2. Existing nonlinear inversion,
source-order decay, accepted-water trace, immutable configuration, endpoint
temperature splitting and S5MT0001 atomic-generation semantics remain unchanged.
The independent literal loop and its real128 nonlinear inversion oracle qualify
this combination at exponents .5/.8/1/1.0005/1.5/2, including refinement and fresh
process restart. Every previously qualified linear endpoint must remain exact.
Outside-domain constructors and analytic heat remain rejected. No pond, seasonal,
full historical/default-file, RossFast or aquifer admission is proposed.
The existing status record's `nonlinear_successor` owns recovery and admission;
the linear predecessor receipt below remains historical, immutable evidence.

Status: canonically admitted bounded numeric-heat/linear-matrix composition,
PR1342 / `7d04b00778684ff662ec36715b7b3e9654b8fb73`. The completed admission
receipt is `integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json` on canonical.
Baseline: `83defb1a6a7a9f4d2fcd862faf73a21ad621072a`.

Admission reconciliation: concurrent canonical `3cb20b8a48440a9445277dfba0982b697197638a`
adds PERF01 diagnostic evidence/registration only. Its complete src/reference
trees equal the original baseline. The exact new predecessor authority is
executed; every previously executed thermal input retains its source hash.

The existing B1.11 sorption, transport and temperature/moisture/depth decay
operators remain the scientific implementation. This successor supplies an
actual, node-resolved restricted-heat endpoint to those operators. It does not
reinterpret the immutable configured temperature vector as mutable state.

One explicit coupling interval first advances Reference water and restricted
soil heat into a detached committed carrier. Its endpoint temperature profile
is held constant while the existing chemical operator consumes precisely that
interval's accepted water receipts. This is endpoint operator splitting, not
historical substep-temperature identity. Interval refinement is a qualification
condition; arbitrary long intervals and seasonal accuracy are not inferred.

The original committed water/heat and chemical owners are assigned together only
after transport, reaction, mass closure and endpoint alignment succeed. A failed
water, heat or chemical trial publishes neither owner. Immutable chemical
parameters, including the original temperature vector, remain byte-identical.
`temperature_active=false` separately retains the source's zero-decay factor.

The bounded domain is numeric restricted heat and linear sorption in one matrix
column. Nonlinear sorption and analytic heat are rejected by this new composition;
their incumbent standalone routes are unchanged. There is no surface input/pond, no macropores,
snow, frost, aquifer, crop/N/age companions or RossFast extension. Existing
Reference trace and restricted-heat contracts remain authoritative. Root,
drain and bottom receipts are the existing accepted water receipts. Geometry,
heat activation, clocks and certified parameter identity must agree.

Invariants affected: 3 (separate state/parameters), 7 (atomic rejection),
13 (mass closure), 21 (reuse physics), 23 (no solver-policy change),
25 (preserve Reference). No incumbent implementation or shared interface is
changed. Disk restart must carry water, heat, chemical inventory, temporal
history and identities as one generation before independent-process admission.

Qualification selects a real production driver at GNU O0/O2, changing thermal
boundaries, literal source-order decay control, heat-off control, chemical
overdraw rejection and smaller retry, hydraulic rejection, geometry and identity
negatives, independent process restart and measured interval refinement.
Unchanged incumbent physical providers retain their existing authority; added
composition is not admitted by a module graph alone.

## Executed qualification

The production entrypoint is `mod_fmr_b111_matrix_thermal_application`; the
executable driver calls it directly. Numeric-heat and linear-sorption guards
reject unsupported compositions before any water revision advances. The
file-driven pond application is not activated by this successor.

GNU 13.3.0 O0/O2 compile all 277 required providers with bounds checks and
invalid/zero/overflow traps. This closure follows from the existing Reference,
accepted-state, bootstrap and disk interfaces; no process physics is copied.
Compile/link costs are 139.686508/0.206933 s, initial native tests 1.365077 s.
Physics-only time is UNKNOWN.

The four-node, 3-cm column starts at 5/10/20/35 C. Prescribed surface temperature
changes from 5 to 30 C halfway through 0.002 day. Actual transport includes root,
drainage and bottom receipts. Each interval's concentration, inventory and decay
are checked against the literal historical loop with independently reconstructed
water faces. The B1.11 source SHA is
`2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2`.
Every interval asserts water closure below 1e-10 cm and solute closure below
1e-11 mg/cm2. These are verification bounds, not a measured water maximum.
Recorded initial-mesh solute maxima are below 9e-16 mg/cm2.

All seven fixed-horizon meshes (2/4/8/16/32/64/128 intervals) decrease successive
mass-vector and cumulative-decay differences. Final differences are
1.0001248052e-8 mg/cm2 per-node inventory and 1.0874885549e-8 mg/cm2 decay;
the latter is 0.00081893587 of total decay. This establishes the tested endpoint
split boundary, not a formal convergence order or seasonal validation. Outer
refinement is explicitly refinement of this thermal coupling operator; actual
accepted water substep counts remain in the raw stdout.

Every mesh restarts halfway through in a new process. O0/O2 and fresh endpoints
are byte-identical; the finest endpoint SHA256 is
`f73b7208d1d010449300971278911745dd38d87dc36b0a3bfa219fbb572786b5`.
Chemical overdraw rejects staged water/heat and chemistry without changing their
serialized bytes; smaller retry succeeds. Invalid water and nonfinite time
reject. The historical heat-off branch gives zero decay.

## Combined restart

`mod_matrix_thermal_restart_file` defines S5MT0001, separate from unchanged
S5MJ0001/S5MJ0002 and S5AJ0001/S5AT0001. One CRC-protected generation carries
water/heat, temporal derivative history, lineage/revisions/clocks, template and
parameter identities, heat/geometry fingerprint, immutable chemical fingerprint
and exact dissolved/sorbed inventory. All decoding and validation precede either
destination assignment. The disk carrier is same-platform temporal-history
Reference, at most 256 nodes; the executed physical claim above is four nodes.

The writer exclusively creates `.pending`, flushes/fsyncs it, atomically renames
the complete file and fsyncs its directory. Failed pending files are retained
fail-closed. Serialized writers and a correctly reconstructed immutable parameter
registry are required. CRC/truncation/overlong, wrong chemical ID/configuration,
changed heat coefficients, wrong physical ID/geometry, negative water, nonfinite
heat and inconsistent clocks/revisions reject without assigning either owner.
Native SIGKILL immediately before/after rename leaves exactly the previous or
complete new generation. The former independently resumes to the uninterrupted
endpoint. Concurrent writers, portable binary ABI and hardware power-loss tests
are not claimed.

Reproduce with `FC` pointing to GNU Fortran:

```bash
python -B tests/nut-sol/run_matrix_thermal.py --output /tmp/thermal-physical
python -B integration/audits/qualify_matrix_thermal.py --physical /tmp/thermal-physical --output /tmp/thermal-qualified
python -B integration/audits/verify_matrix_thermal.py
python -B integration/audits/verify_matrix_thermal.py --self-test
```

The capsule is `integration/audits/evidence/MC_SOL01_DYNAMIC_DECAY_20261021.tar.xz.b64`,
decoded SHA256 `3b8632917226aee433546a358f7346e4e72be7dbdade67363e82fcc1795150f6`.
It retains final raw commands/results, oracle and endpoints, earlier successful
observations and failed compiler/fixture/reporting diagnostics. Current proof is
bound to final executed input hashes. Exact predecessor validation preserves
incumbent SOL/age/NUT/PERF01 authority; unchanged models are not rerun merely
because this isolated composition was added.
