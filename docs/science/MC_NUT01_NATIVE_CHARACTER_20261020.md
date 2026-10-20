# MC-NUT01 native CHARACTER input and disabled extended diagnostics

Baseline: canonical `f6d5ffed068efcc8cc2b14d0b68bb508b7a25f52`.
Owning record: `native_character_successor` in the existing
`integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json`.
This is a bounded input successor, not complete MC-NUT01 admission.

## Historical contract and implementation

The unmodified original TTUTIL library, decoded authority SHA256
`ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`,
accepts concatenated apostrophe strings, including repetition of the joined
value. For example, `2*'Mineral'//' ! fertiliser'` yields two equal names.
`management_soil.f90` reads `MatName` through `rdfcha` into 25-character material
names. Names describe materials; event `iMat` still selects definition row
positions, not label lookup keys.

The existing `read_snm_array_line` now normalizes same-record apostrophe
concatenation before the incumbent material-table parser. No second material
owner, event queue, stock, rate, flux or new state schema is introduced. Both
native named arrays and material table rows use the same normalization.
The existing table parser keeps its length, printable-character, positional,
numeric-range, cardinality and atomic publication checks. The modern export
reader is unchanged. Existing standalone double-quoted input is preserved;
new concatenation is limited to the original apostrophe syntax and spaces.

| Native input | Original TTUTIL result | Current successor |
| --- | --- | --- |
| `'Mine'//'ral'` or `'Mine' // 'ral'` | Joined CHARACTER value | Normalized to the existing name |
| `2*'Mineral'//' ! fertiliser'` | Two joined values | Same repeat scope |
| Empty CHARACTER piece | Rejected | Rejected |
| Tabs around `//` | Rejected | Rejected |
| Doubled apostrophe escape | Rejected | Rejected |
| Numeric or missing right operand | No admitted CHARACTER value | Rejected atomically |
| Native `flCropExt=.FALSE.` with any letter case | Logical false | Accepted as equivalent to omission |
| `.f.`, bare `false`, or numeric `0` | Syntax/type rejected by `rdslog` | Rejected |
| `flCropExt=.TRUE.` | Enables original separate diagnostic file | Remains rejected; output owner is unadmitted |

The named reader admits explicit false only in native mode. It consumes the
flag without adding persistent state. Duplicate flags, true and malformed
logical values do not publish an initialized plan, soil state or parameter set.
The optional flag does not silently enable partial diagnostic output.

The original extended output includes N uptake and residue terms plus P values
calculated as 0.1 times N. These P columns are historical diagnostics, not a
migrated phosphorus process. Supporting `.FALSE.` does not claim that the
extended CSV or its final rewrite is implemented.

## Daily calendar boundary

Original TTUTIL accepts `1901-01-01_12:00:00` and returns day366.5 in its day1
origin. The literal original management gate is:

```fortran
if (abs(TimeAmend(isme) +1.0d0 - t1900) < 1.d-3) then
   call Wofost_SoilAmendents
   isme = isme + 1
end if
```

The independent original-library driver executes that extracted gate unchanged,
with a counter replacing only the physical amendment call. At integer day-end
calls367 through370, an event at366.5 never fires and leaves `isme=1`, thereby
blocking the following integer-date event. A positive control with dates366 and367
fires exactly twice. This is a **process/control fixture**, not a complete original
crop/water/N calculation. It establishes the mismatch between permissive date
reading and actual daily amendment execution. It does not justify inventing
subdaily amendment integration or rounding fractional events into another day.
Near-integer times within the original 1e-3-day gate tolerance are not covered by
this half-day witness. Fractional experimental-humus start dates remain a separate
unqualified threshold-clock envelope.

## Qualification and preservation boundary

The two changed production providers are the unified native reader and named
Soil-N reader. All physical implementations, accepted atmosphere, transport,
crop/root state, rollback, restart and tolerances remain unchanged. The existing
full HIST runner recompiles its actual production closure at O0/O2, with all
source-profile names expressed using concatenation and native `.FALSE.`.
Default, source124-day, four730-day profiles and the12-day accepted-atmosphere
profile remain selected, including all52 transition fresh-process continuations,
other source/default continuations, water/chemical/clean-only rejection and
independent historical chemistry/crop assertions.

Admission requires all14 endpoint files and every reported observable to equal
the immutable admitted PR1333 capsule exactly. The new guard checks current
source and actual compile/link/native inventories, complete current parser
input matrices, independent original outcomes, raw logs and restart bytes.
It executes the complete original owning authority and its9 corruption controls
unchanged at exact predecessor f6d5ffed. No old archive or old input hash is
rewritten or projected into a current source reader.

Retained/thermal/TCS6 science and their old inputs are preserved through that
original authority, after fresh complete physical and parser equivalence checks.
These are inherited scoped qualifications, not newly executed thermal or TCS6
calculations. All178 actually compiled MC-SOL01 application providers remain
byte-identical. Three independent existing CI compilation footprints exclude
both changed parser providers. Full moving F-CI, RossFast and highest low-air
are not selected for this bounded input change.

The unchanged native suite has38 fixtures. The unchanged modern-export suite
currently reports53 fixtures and3075 Gregorian-date checks. Historical prose
mentioning55 is not the count of this actual current runner. The supplement
executes18 native cases and13 original outcomes at each optimization, including
the literal daily gate. Live object/module/executable bytes for the reused native
build are hashed before and after supplementation; every new case executes.

## Reproduction

Use GNU Fortran13, one OpenMP thread, unlimited stack for the coupled model,
and fresh directories. The original reader runner uses `FC`; incumbent runners
resolve `gfortran` on PATH.

```bash
export OMP_NUM_THREADS=1 PYTHONDONTWRITEBYTECODE=1
ulimit -s unlimited
N_NATIVE_RESULT_DIR=/tmp/character-native python tests/nut-input/run_native_snm.py
N_NATIVE_RESULT_DIR=/tmp/character-native N_CHARACTER_RESULT_DIR=/tmp/character-direct \
  python integration/audits/run_nut_native_character.py
N_INPUT_RESULT_DIR=/tmp/character-modern python tests/nut-input/run_input.py
REPRODUCTIVE_PROCESS_RESULT_DIR=/tmp/character-literal \
  python tests/nut-crop/run_reproductive_process.py
N_HIST_RESULT_DIR=/tmp/character-physical \
  REPRODUCTIVE_LITERAL_FILE=/tmp/character-literal/literal.f90 \
  python tests/nut-crop/run_hist_complete.py
python tests/nut-crop/verify_hist_native_successor.py
python integration/audits/verify_nut_native_character.py --self-test
```

The owning status identifies immutable evidence, measured costs, actual
qualification/admission state and canonical receipts. Negative source forcing,
persistent ponded N, snow/interception, remaining grammar and extended diagnostics,
and complete original-model regression retain their separate recorded limits.

## Fresh numerical results

GNU Fortran13.3 O0/O2 both pass. All14 endpoint bytes and every reported
observable equal the admitted PR1333 results exactly, including all52 transition
continuations and rollback bytes. The following ledgers come from the actual
coupled Reference/crop/Soil-N runs, not the syntax or original calendar fixtures.
All N amounts are kg N/m²; relative residual is absolute signed residual divided
by initial stock plus external input.

| Actual profile | Initial | External input | External output | Final | Signed residual | Absolute relative residual |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| rotation-profile | 0.66569153059254693 | 0.097089249304468814 | 0.012370661578694379 | 0.75041011831832038 | 9.9573127521068727e-16 | 1.3054e-15 |
| atmospheric-profile | 0.66569153059254693 | 0.013678071059048533 | 0.0077548447218841101 | 0.67161475692971284 | -1.5178830414797062e-15 | 2.23425e-15 |
| humus-profile | 0.66569153059254693 | 0.013678065024113333 | 0.0078191758442261276 | 0.67155041977243912 | -5.0341675272846942e-15 | 7.41006e-15 |
| gross-profile | 0.66569153059254693 | 0.019448273121288662 | 0.0080723769466728382 | 0.6770674267671648 | -1.9931972738973514e-15 | 2.90918e-15 |
| surface-profile | 0.66592190132155538 | 0.0062479886961157695 | 0.00032461208981581679 | 0.67184527792785542 | -1.0446287931897835e-16 | 1.55411e-16 |

The unchanged daily/cumulative N tolerances are1e-12/1e-10kg/m². The accepted
water closure tolerance stays1e-10cm. The730-day profiles retain their preceding
measured physical boundary regimes; this parser change introduces no new forcing
or source convention. Current cumulative ledger residuals range from about1e-16
to5.04e-15kg N/m². No full historical multiyear-model comparison is inferred.

Fresh physical costs: compile221.328849s, link0.636961s, native167.232173s,
fresh-transition native169.068435s. Additional compiler-version/trace-controller
events are retained separately. Physics-only timing is UNKNOWN. Direct native38
cost5.201852s compile/0.083780s link/0.492041s native; modern53/date3075 cost
1.222151s provider compile/0.106844s driver compile/0.070626s link/0.245985s native.
The18-case supplement plus independent original13 outcomes/optimization costs
10.399479s original compile/0.183695s original link/0.153593s current native/
0.083258s original native. These are execution measurements, not speed claims.

## Evidence and owning controls

Immutable numerical capsule `integration/audits/evidence/MC_NUT01_NATIVE_CHARACTER_20261020.tar.xz.b64` has decoded SHA256
`f7969b3db4f55202c564e960450138be990c59b1b7cfe645a5ba541a76d31af4`, 233,288 compressed bytes and
4687 members. It retains the final source/current/original/physical
receipts, source fixtures, native restart payloads, raw command streams and member
hashes. Failed early empty/tab assumptions and their exact source postimages
are retained separately inside the same capsule. Reproducible objects/modules
and ELF executables are omitted. The first evidence-validator attempt discovered
that the incumbent native runner names raw files by event index instead of
recording paths; the validator was corrected without rewriting that inventory
or rerunning unchanged successful science.

The new11 corruption controls and actual current NUT/grid entrypoints pass.
The full original owner and9 controls execute unchanged at f6d5ffed. Concurrent
MC-SOL01 PR1336 (`8d3689fc`) is reconciled without changing its dry-profile
evidence or any of its178 current compiled providers. Canonical admission is
recorded separately in the existing status; qualification alone is not admission.
