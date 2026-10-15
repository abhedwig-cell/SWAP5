# Amendment input recovery

Work unit MC-NUT01-AMENDMENT-INPUT, owner MC-NUT01. Baseline
`7c774455bf1d5918b76d6147a23cc159ba427e8b`; branch
`work/nut-amendment-input-20261015`. Status:
`integration/audits/MC_NUT01_AMENDMENT_INPUT_STATUS.json`. The
[input contract](MC_NUT01_AMENDMENT_INPUT_CONTRACT_20261015.md) is the scope
authority; the status and PR merge receipt establish qualification/admission.

## Implementation and ownership

One additive producer, `src/process/mod_soil_n_amendment_input.f90`, reads an
explicit bounded two-table management export. No complete legacy SNM/project or
TTUTIL compatibility or default activation. Recognize original field names,
position1..20 material association, explicit Gregorian midnight dates, original
kg/ha and ordered equal-date events. Dates use an explicit origin; conversion
to kg/m2 remains solely in the admitted calendar. Unsupported syntax and late
errors invalidate the whole result. File/record bounds prevent truncation.

No existing production provider, physical formula, solver, tolerance, inventory,
state interface, restart schema, WOFOST81 fixation or runtime publication owner
changes. The reader owns transient external forcing only. Restart callers supply
the next plan again; no persisted forcing cursor is introduced. Invariants3/4/7/
9/13/21/23/29/30 remain binding.

Existing calendar guards dispatch to a strict input successor only after complete
delta, postimage and native proof checks. The old canonical calendar gate and183
controls execute at the exact baseline in an isolated worktree. The CO2 guard
exempts only the verified additive set. Full moving recognizes the new producer
through the existing material owner; it does not skip that owner gate.

## Completed science

Fresh actual production builds and execution at O0/O2:

| Boundary | Closure | Evidence |
| --- | --- | --- |
| Input/calendar |4 providers |53 file fixtures,45 invalid cases,3075 independent Python Gregorian/date expectations, finite/domain/capacity/syntax checks, failed-read reset and A/B/A selection |
| Actual crop/soil day |47 providers |Original complete day driver with only its plan producer changed to file input; literal pools, supply, delayed crop residues, whole N, rollback and replay |
| Actual Richards |267 providers |Original complete driver with manual/typed/file profiles; literal eight pools and mineral supply, accepted water, crop and pending residues, rejected/retried days, complete native/opaque and fresh-process restart |

Manual, typed and file complete native endpoints agree bytewise, including
optimization identity. Existing physical assertions remain intact. Generated
driver bytes and their deterministic bounded transformation are retained and
verified against the original versioned driver. No cached build objects or
copied native PASS. Fixtures are derived management exports, not authentic old
project files. The old source authority and its already admitted organic R2
correction are checked bytewise inside the composed evidence.

Measured direct input compile0.969s/driver0.129s/link0.061s/native0.202s;
day14.737s/3.690s/0.089s/0.015s; joint145.649s/14.386s/0.540s/175.101s.
Per-physics timing UNKNOWN. Retain the initial failed header-width run and the
first passing process run as historical attempts, separate from final proof.
The final producer bytes are those in all passing physical executions.

## Qualification and continuation

Read current status for completed raw/source/negative/docs gates and the selected
full run. Running is not PASS. One stable full local moving OFF is selected at
admission (expected1677s), because this external input now feeds actual accepted
Richards days. No duplicate Actions. Highest low-air NOT_SELECTED_POLICY.

After terminal full PASS, bind its exact execution tree, source and unchanged
tracked inputs, persist raw logs plus dependency-aware metadata closeout, then
check live canonical/PR overlap and expected head before merge. The frozen status
may retain `canonically_admitted=false`; only the PR's canonical merge receipt
admits this bounded scope. No capability or denominator promotion.

Complete legacy-file/default activation, accepted heat/profile coupling,
harvest/reset/rotation and simultaneous companions stay open. Surface input
PR1234 and crop trajectory PR1241 remain separately owned. Pond/source open;
aquifer rejected. Continue from this work unit instead of replacing or reopening
those routes.

## Explicit caller example

Illustrative derived management export, not an authentic historical project file:

```text
MatNum MatName AppAge OrgMatFrac OrgNFrac NH4NFrac NO3NFrac
1 'Mineral blend' 0.0 0.0 0.0 0.21 0.10
smedate iMat Dosagekgha VolatFraction
2026-01-01 1 100.0 0.1
```

The caller invokes `read_soil_n_amendment_tables(path,'2026-01-01',plan,status,error_line)`
from `mod_soil_n_amendment_input`, requires `N_INPUT_OK`, then passes the plan to
the existing calendar day or Richards entrypoint. It must align the physical
clock with the returned1900-based day convention, available through
`parse_soil_n_date`. The file does not activate a simulation or set its clock.
No existing kernel/runtime module imports the reader; this translation boundary
is explicitly invoked by the caller, preserving invariant2.

## Terminal premerge receipt

One full local moving OFF completed PASS in1998.761113s at
`99af2a27b919bd9afdd3d14bd4ee5f6643a496fb`, tree`943a75381928ebf16f98d5e71bf8c0146cc25425`. All6398
tracked inputs remained unchanged. Source tree`7d397ea67d8106756c08f375f2098776aea64d3e`.
Owning controls245 PASS; source/docs/strict build PASS. Full raw evidence, logs,
execution bundle and final metadata-only dependency binding are in the admission
capsule indexed by status. No hosted dispatch and no highest low-air run.
See the [bounded coverage receipt](MC_NUT01_AMENDMENT_INPUT_COVERAGE_RECEIPT_20261015.md).
