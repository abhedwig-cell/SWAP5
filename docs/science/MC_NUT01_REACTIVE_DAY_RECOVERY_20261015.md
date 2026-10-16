# MC-NUT01 reactive daily qualification and recovery

This work continues canonical PR #1231 at
`eb03024d99ef9256335eb6e2f3f74bccce8145f0`. The single successor PR is
[#1232](https://github.com/abhedwig-cell/SWAP5/pull/1232). Its versioned status is
`integration/audits/MC_NUT01_REACTIVE_DAY_STATUS.json`; actual canonical
admission requires the final PR merge/source/tree receipt.

The new explicit application entry point is `run_reactive_n_joint_interval`.
It advances real Full Richards water and a reactive daily N candidate atomically.
One existing mineral owner retains FOM/Bio/Hum, NH4/NO3, the consumed clock and
revision. The reactive wrapper adds immutable process configuration, not a second
inventory. `aggregate_mineral_trace` exposes a read-only accepted daily carrier;
`apply_mineral_day_transfer` validates the candidate budget before publication.
The original four-provider mineral process route remains independently runnable.

The source sequence is organic reference rates corrected for prescribed
isothermal temperature and moisture; exact FOM/Bio/Hum turnover; carbon
dissimilation; respiration limitation of denitrification; analytical NH4
production/transport/nitrification; analytical NO3 production/transport/loss;
whole-N commit. Nitrification is internal; denitrification is an explicit gaseous
N output. Positive mineralisation credits NH4. Immobilisation debits NH4, and
insufficient available mineral N rejects the complete candidate. Rejected water,
carrier or organic trials leave both committed owners unchanged.

## Corrected reference MC-NUT01-R1

The original B1.11 `wofost_soil_orgmatn.f90`, SHA256
`85146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6`, subtracts
the Bio incorporation term twice in the later Nminer FOM expression. The detailed
organic-N balance uses Bio plus Hum. The reference transform replaces exactly the
second duplicated Bio term by Hum, before production is qualified. The original
defect witness and corrected-source whole-N qualification execute first at each
optimization. Full literal historical declarations, orgmatn, rateconstants and
watern routines are compiled as the oracle. The exact one-replacement pre/post
bytes, hashes and ordered native events are retained in the capsule and
`MC_NUT01_ORGANIC_REFERENCE_TRANSFORM_20261015.json`. The immutable global B1.11
archive/reference manifest is unchanged; this is no global B1.12 release claim.
See `MC_NUT01_ORGANIC_REFERENCE_DECISION_20261015.md` for the scoped authority.

## Local qualification

`python -B tests/nut-reactive/run_reactive.py --direct` builds thirteen real
production providers. It executes sixteen temperature/moisture environments,
source-derived full organic/mineral endpoints, nitrification, carbon respiration,
gaseous loss, moving water, explicit off mode, replay, insufficient-N rejection
and opaque continuation. The independent edge runner additionally proves
successful immobilisation, internal nitrification without a false external sink,
water mismatch rollback, revision-domain failure and extreme public-transfer
rejection before overflow. Exact commands, compiler flags, inputs and raw native
outputs are versioned; separate O0/O2 directories are used.

The complete runner calls actual two-day Richards/reaction production: outflow
then inflow, nonzero root water, actual legacy daily balance reconstruction,
organic turnover and gas loss, hydraulic and chemical failure followed by a
valid retry, nine malformed carrier cases, opaque restart and independently
resumed disk continuation. Ten malformed disk cases reject. Three further
recomputed-CRC mutations test organic-rate, temperature and enabled-mode identity.
All continuation endpoints match byte for byte across O0/O2. The original admitted
mineral physical driver and ten decoder negatives execute fresh on the same
controlled provider build, preserving its original assertions. Its water/N
endpoints equal the previous admitted capsule byte for byte. Explicit off-mode
water/N endpoint files also equal the original mineral operation. A separate
four-provider feedback run stays small. Twenty-six source/evidence mutations are
rejected; both exact source and all raw terminal proofs are checked.

The four-provider predecessor, thirteen-provider new process and independent
edge builds remain small. The actual joint physical closure contains 250 providers
because it imports the real accepted water/temporal-history/kernel/restart owner
and original regression driver. The controlled shared build preserves all native
driver executions; no cached scientific result substitutes for them. The pilot
and stable execution are both retained; stable valid endpoints also equal the
pilot after the public-transfer domain guard was added. Physical source tree:
`6839bb0ddc6be7a6be81954206ee3f7e6cc5a975`.

## Preserved scope and remaining queue

The explicit profile is one full modeled column, exactly one day, zero top flux
and ponding, no macro/SSDI/optional chemical stores, and no opposing external
inflow/outflow. Prescribed temperature/configuration is fixed for this isothermal
profile and included in restart. This does not integrate a daily heat-state
forcing, humus exponential calendar, amendments/residues, crop-N supply/demand,
fixation changes, general solute or simultaneous matrix-plus-N application.
Keep accepted WOFOST81 fixation semantics in subsequent crop-N work.

Full moving preservation is selected once for the changed N owner/carrier and
admission guards under the existing four-level admission boundary. It runs with
FCI_RESUME_MODE=OFF. The original incumbent owner verifier executes unchanged at
the exact accepted baseline after strict new-postimage/physical proof checks.
Long highest-low-air stress remains NOT_SELECTED_POLICY. No blanket hosted-CI
claim is made.

The current master1072 head `53eb3d2f1e14d7b48efdd8d942f42f1422f4ac3a` still
claims that no Soil-N owner exists. That is already stale after canonical PR #1231.
The precise seven-row correction and old-row hashes are recorded in
`MC_NUT01_REACTIVE_COVERAGE_RECONCILIATION_20261015.json`. Full capability
dispositions remain unchanged: 243 total, 95 admitted, 108 active, 14 superseded,
2 rejected, 20 not applicable and 4 qualification-only. This is a structural
recount and bounded production receipt, not a global coverage-integrity PASS.
The independent master branch is untouched.

Next dependency-ready work is an explicit daily environmental forcing contract
where needed and crop-N supply/demand over this shared N owner, retaining WOFOST81
fixation semantics; then source-qualified amendment/residue events. The broader
NUT/SOL donor PR1117 remains open for its remaining scope.

Terminal full moving result: **PASS**, return0, FCI_RESUME_MODE=OFF, wall 1423.361 seconds, 6258 tracked input hashes unchanged during execution. Actual execution 3b60b7e1ee3bfea72fd5fac99a000dda8c2e4020; source tree 6839bb0ddc6be7a6be81954206ee3f7e6cc5a975.

The status is the frozen premerge receipt. Read [PR #1232](https://github.com/abhedwig-cell/SWAP5/pull/1232) for its actual merge and canonical source/tree verification. Closeout preserves the exact full-run receipt and reconciles the separately admitted nonlinear peer with explicit guard-only qualification. Original scientific inputs remain exact. The later independent nonlinear admission is reconciled through pinned canonical-relative source guards; their requalified composition is recorded separately below.


## Concurrent canonical nonlinear reconciliation

Canonical advanced from eb03024d to 9ed5efc773b28f44b16b8922730b3fd9b8892b60 via PR1230. The final combined source tree is 1c7be316f404f6d75881e14393fe00634f6885f7. All253 reactive science inputs remain byte-identical, including all providers and actual joint tests; the nonlinear constructor is outside that closure. All240 nonlinear inputs and raw terminal proofs validate on the combined tree. Exact canonical-relative source guards reject foreign peer/source/test changes and missing terminal peer evidence. Twenty-six reactive controls, thirteen nonlinear controls and three extra peer negatives pass. Both small real production O0/O2 closures execute fresh. Original CO2/mineral owning assertions execute at the exact admitted peer baseline after complete union/physical proof checks; ordinary owning CLIs pass. Full preservation is inherited from the unchanged surfaces of the actual reactive run above and the independent nonlinear run1829.803s, not relabeled as a new combined run. No simultaneous matrix-plus-N application is claimed. Raw peer scripts/logs/results and an exact combined Git bundle are included in the admission capsule.
