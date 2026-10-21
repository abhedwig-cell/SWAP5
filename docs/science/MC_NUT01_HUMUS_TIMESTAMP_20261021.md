# Historical humus timestamps

Candidate, MC-NUT01, science execution baseline d7b89175 (21 October2026),
composed canonical bcf7a497. Concurrent PR1353 changes the F-SI35 evidence/registry
only; all production sources and every executed NUT provider stay identical.
The existing HIST-COMPLETE status remains the admission authority.

Original archived TTUTIL RDDECT in rdlex.for accepts a date followed by an
underscore and hour:minute, optionally seconds and fractional seconds. DTARDP/
DTSYS maps this to a double precision ordinal day; fractional seconds first pass
through the original default REAL. SoilManagement selects the humus experiment
using the already established interval-endpoint predicate. A fractional clock
does not split an original daily chemistry calculation at that clock.

This extension supports the existing numeric YYYY-MM-DD and DD-MMM-YYYY dates
with `_HH:MM`, `_HH:MM:SS` and fractional seconds. Date-only input remains exact.
Original hours24..99 normalize into following days; a trailing seconds decimal
point means zero fractional seconds. Both details are retained, and the original
day1 arithmetic order is preserved before conversion to SWAP5 day0. Wider hour
field widths and other date spellings are outside this bounded input extension.
Only tstartHumexp gains this grammar; amendment event dates remain daily. Source
activation and the existing reactive parameter validator accept finite ordinal
fractions within their existing range. Absent/disabled experiment constraints
remain unchanged. No process equation, state, restart schema or solver changes.

Qualification selection: original TTUTIL O0/O2 interpretation including invalid
clocks; actual native input atomicity and physical source-line mapping; original
rateconstant endpoint selection and real reactive-owner fractional-switch/restart
controls; targeted accepted Reference/crop/Soil-N composition across that switch.
Prior full HIST/retained evidence is preserved only by an exact old-domain body
proof and current dependency check, never by relabelling a fixture as a model.
Expected direct feedback below60seconds; full composition build cost is UNKNOWN
until measured. Existing unchanged solver/RossFast/aquifer gates are not selected.

Invariants: historical units/order and parameter identity; accepted-state-only
publication, atomic failure, mass conservation and persistent restart. Remaining
negative active-crop and automatic surface contracts are outside this extension.

## Completed local qualification

Twelve source timestamps, including leap day, normalized hours, fractional seconds
and trailing decimal point, are bit-identical to the unmodified TTUTIL at O0/O2.
Nine malformed/invalid inputs reject on both sides. All38 incumbent native
fixtures pass unchanged. Real reactive-owner tests execute original rateconstant,
organic and transport routines for integer and fractional clocks, including
strict activation threshold, mass and opaque continuation.

The complete incumbent HIST matrix was rebuilt from current source:16 endpoints
remain exact, with56 prior transition continuations and original assertions.
Measured cost:223.17s compilation,0.66s linking,12.46s native models and31.23s
fresh restarts. This is physical coupled qualification, not just module imports.

Four additional actual Richards/crop-day/harvest/12-day fallow/N calculations use
native clock1900-01-07_12:00, real humus turnover, low/high mineral stocks and
accepted wet/drying water steps. Eight new process restarts span the switch;
native state and15-field cumulative books are exact. Water and chemical rejection
preserve committed bytes. Eight whole-day controls prove the daily endpoint
predicate: the fractional run equals its ceiling-date ledger and differs from
its floor-date ledger. O0/O2 endpoints and journals are exact.

| Availability | Initial N | Input | Output | Final N | Absolute residual kgN/m2 | Relative residual |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Low | 0.49741711989702270 | 0.000056 | 0.00057373912321242678 | 0.49689938077381135 | 1.0547118733938987e-15 | 2.1201384179555724e-15 |
| High | 0.50038706256364762 | 0.000056 | 0.0035436245691658152 | 0.49689943799448155 | 2.2204460492503131e-16 | 4.4369603964045585e-16 |

Relative residual uses initial N plus input. Existing hard gates remain1e-12kg/m2
daily and1e-10kg/m2 cumulative; the latter equals1e-6kg/ha. Forty kg/m3 humus in
these controlled fixtures makes the event chemically observable. This is not a
calibrated site or complete historical multiyear replay.

Raw successful/failed attempts are sealed at
`integration/audits/evidence/mc-nut01-humus-timestamp-20261021/INDEX.json`, decoded
SHA256 `25b417382298b6bcbe240d9a388e35740ca1a53fa7fbe475e61261e2561b36a9`.
The first test classified24:00 incorrectly; actual TTUTIL rejected that test
assumption, the implementation/matrix were corrected, and the failed attempt is
retained. No original routine or tolerance was weakened.

Reproduction from the repository root, GNU13.3, unlimited stack and one OpenMP
thread:

```bash
export OMP_NUM_THREADS=1 PYTHONDONTWRITEBYTECODE=1
ulimit -s unlimited
python -B integration/audits/run_nut_humus_timestamp.py --output /tmp/nut-clock-native
N_NATIVE_RESULT_DIR=/tmp/nut-clock-legacy python -B tests/nut-input/run_native_snm.py
REACTIVE_RESULT_DIR=/tmp/nut-clock-reactive python -B tests/nut-reactive/run_reactive.py --direct
```

Generate the existing reproductive literal and execute `run_hist_complete.py`
with its documented SHA256 and `N_HIST_RESULT_DIR=/tmp/nut-clock-physical`.
Then execute:

```bash
python -B integration/audits/run_nut_humus_joint.py --physical /tmp/nut-clock-physical --native /tmp/nut-clock-native --output /tmp/nut-clock-joint
python -B integration/audits/verify_nut_humus_timestamp.py
python -B integration/audits/verify_nut_humus_timestamp.py --self-test
```

The last two commands validate versioned raw evidence and current source. They
are not fresh numerical execution. Default/daily chemistry bodies are unchanged
except removal of two integer-clock rejection predicates; the source owner
checks that exact projection and the unchanged native reader outside the private
decoder. Current SOL/PERF executed providers remain independently validated.
