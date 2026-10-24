# Failed near-zero Picard restart

Bounded numerical repair,24 October2026. Qualification baseline
`367c11e394e3f166f861d9f1502aaeeda01215d7`. The same production HeadCalc remains
responsible for every solve; no physical equation, boundary law, state layout,
time-step tolerance or mass criterion changes.

Modified Picard evaluates candidate conductivity K(h), but omits its derivative
from the iteration matrix. At the continuous Mualem saturation corner that
omission can prevent convergence even as transaction retries shrink dt. Real
12-cell failed requests were captured without changing their accepted outputs.
The1x captured request is repaired directly. The first4x request still advises
retry; its divide8/16 trials converge with the repair while the predecessor
rejects. Still smaller trials are not uniformly successful. No general
monotonic-in-dt convergence claim is made.

Preserve every successful ordinary phase. After failure only, restore the exact
entry trial state and retry once with the already implemented consistent K(h)
Jacobian. Modified Picard already used candidate K(h), so this changes iteration,
not the residual being solved. No physical origin is clipped or adjusted. All
original convergence, compartment/total mass, retry and transactional acceptance
gates still apply. Caller configuration is immutable; the switch is local to
one HeadCalc invocation. Existing excluded routes retain their old behavior.

Eligibility is explicit: nonlegacy default MvG with continuous saturation
conductivity, modified Picard, dynamic top, bottom mode2, SWKIMPL0/SWKMEAN1,
no consistent-policy request, matrix scaling, macropores, elastic storage,
KSATEXM or conductivity power tail. At least one original node head must be
within sqrt(machine epsilon) cm of zero. The bound is the existing numerical
corner scale, not a new physical classification threshold.

Qualification uses a21-provider real production-driver closure at O0/O2,
predecessor rejection, independent compartment finite-volume balance, immutable
input, caller policy, rejected-state and A/B/A scratch checks. Current checked
application builds complete481days at1x/4x with exact O0/O2 physical bytes and
exact day240 disk continuations. The application stress still uses explicit
research endpoint/cap settings: those settings are not admitted by this repair.
Existing positive-chemistry BBC/Cauchy481-day and original flux481-day outputs
remain byte-identical to their admitted predecessor, including BBC day365
continuation. Eight current Richards/crop/N joint runs and16 independent process
continuations pass; retained nonjuvenile endpoints/ledgers are exact.

Current source-bound owner,12 corruption controls and the complete existing
F-CI93/F-SI35 source/native preservation gate pass. Frozen predecessor25 controls
remain dated evidence. No full MC-SOL01/MC-NUT01 or master promotion, wider
Boesten endpoint/output-amount policy, capped execution policy, RossFast expansion,
new1e-6 temporal test or heavy low-air qualification follows.

Authority and recovery: `integration/performance/PERF01_PICARD_CORNER_STATUS.json`,
`integration/audits/verify_picard_corner_current.py`, the manifest-bound
`benchmarks/performance/PERF01_PICARD_CORNER_20261024_EVIDENCE.tar.xz` and separate
actual-merge receipt. Performance measurements remain scoped observations;
this is a robustness repair rather than a portable speed guarantee.

Concurrent admission reconciliation: canonical32676715 adds only three mode3/
macropore guards in the adapter/backend. The repaired nonmacro Picard2 numerical
branch is unchanged. Both changed providers were recompiled atO0/O2; their
compiled public interfaces are byte-identical.108 current independent macro/
Robin cases and both current positive-chemistry BBC481 executions pass, with
all retained physical bytes exact. The complete macro predecessor17 controls
remain frozen evidence. The earlier full481/NUT results retain their exact
executed source bindings; the owner explicitly validates this guard-only
projection instead of presenting them as freshly rebuilt after that delta.
The predecessor macro assertions are preserved by the new owning dispatch.
Two raw captured fixture files deliberately retain original Fortran whitespace;
code-only Git whitespace checks exclude these literal input records.
