# F-CI safe-resume experiment result

Status: bounded scientific comparison completed and opt-in scope canonically
admitted on 13 October 2026 via PR1217. All four automatic post-merge workflows
subsequently completed successfully. PR: https://github.com/abhedwig-cell/SWAP5/pull/1217. Design and recovery:
[FCI safe resume](../development/FCI_SAFE_RESUME_20261012.md). Exact actual execution
head for OFF, controlled SHADOW prefix and RESUME:
`dd3c823b14ab1e49b1604482de5214ea1f77879a`.

## Final closed-profile qualification

The final 33-control safety matrix ended with exit 0. The fresh complete OFF,
controlled SHADOW interruption and complete RESUME used the same functional
candidate above. Both full runs ended with exit 0; the harness also ended with
exit 0. The interrupted prefix ended with intentional outer exit 1 after both
eligible groups had recorded authenticated terminal PASS. A running or interrupted
group was never inherited. The focused trial separately exercises mid-group
interruption, full identical-input SHADOW and independent downstream compilation.

RESUME inherited exactly `frost-invalid` and `frost-independent`. Every remaining
original command and argument executed in the same order. Complete scientific
stdout is identical after the same nine narrowly anchored temporary-path
normalizations described below. No number, optimization, case, tolerance or
scientific assertion is normalized. Both normalized streams have SHA256
`df4ee0b0856f55f09db7372d8b80d2296f55252bb8f4d1aa1225e7c873604a21`.
Original stdout hashes are `cce01c9da3655f21ea28bab74df0b14cd0c5992f7eafaa32be4b0f29706260a9`
(OFF) and `acd94d781f6392d755a578863a16e365f1cf9428b5ce75a5a159f7a17b986c3c`
(RESUME). Both HMAC signatures, complete logs and start/end input identities were
additionally checked from the original receipts with the separately retained key.

| Final-candidate measurement | Actual observation |
| --- | ---: |
| OFF baseline calendar duration | 2398.644100 s |
| RESUME/recovery execution calendar duration | 2405.963222 s |
| Completed interrupted prefix | 10.024211 s |
| Observed whole-run improvement | -7.319122 s; RESUME was longer |
| Original top-level calls | 26 OFF; 24 RESUME, including four pure verifiers each |
| Scientific top-level groups | 22 executed OFF; 20 executed and two inherited RESUME |
| Compile/link invocations actually avoided | 8; repeated in inherited leaves: 0 |
| Executed wall time of omitted leaves | 1.409290 s; execution and log I/O, not pure CPU |
| RESUME input/evidence verification | 1.599199 s |
| Initial prefix input verification | 1.837247 s |
| Post-execution input revalidation | 1.651413 s |
| Atomic terminal receipt publication | 0.006220 s |
| Pure compilation CPU saved, other compile totals, separate recovery CPU | UNKNOWN |
| Warm filesystem/cache and host-load contribution | UNKNOWN; no object cache enabled |

There is one ordered full pair for this functional controller. Earlier pairs used
different controllers and are not statistical repetitions. Verification alone
exceeds omitted group execution by 0.189908 s. This proves safe bounded reuse and
actually avoided work, not a net speedup or a portable performance improvement.
OFF stays default. Conservative FFLAGS invalidation and the repaired CPU JSON
representation error are disclosed extra-RUN cases; final negative controls have
zero false inheritance. Broader groups remain RUN pending their own closure proof.

Final original logs, controls, authenticated manifests, measurement calculations
and executed commands are in
`integration/f-ci/evidence/F-CI_RESUME_CLOSED_FULL_20261012.tar.gz.b64`, decoded
SHA256 `37aa4bc207a7371f16c277271d43042bbc5e2da4bbf979d31a6a2e54bad78563`.
The private key is deliberately absent. Recompute from the decoded directory:

```bash
python tests/fci/summarize_resume_trial.py full-closed-final
python tests/fci/summarize_resume_trial.py full-closed-final --key /private/retained-key
python tests/fci/compare_resume_trial.py --self-test
```

Without the private key the summary reports HMAC verification UNKNOWN, while
checking recorded log/control SHA256 and scientific equivalence. It does not
issue a scientific PASS or create reusable receipts. The actual RESUME controller
and the independent keyed summary both verified signatures during this experiment.
The measurement helper was added at documentary closeout; it does not alter the
tested controller, outer runner or physics. Use the PR closeout checkout for the
offline helper and the recorded actual candidate for a new scientific replay.
Documentation source checks and strict MkDocs build both completed with exit 0;
the comparator mutation self-test also ended with exit 0. All 32 recorded focused
case-log hashes were rechecked, and the 33rd independent downstream result has
exit 0. The first recheck incorrectly assumed that downstream also had a recorded
log hash and raised KeyError; the corrected check does not invent that identity.

The following review chronology and older measurements remain attributed to
their exact earlier candidates. They are not qualification of arbitrary future
source, toolchain or control revisions.

## Continuation review: eligibility defect and hardening

The continuation review reproduced a real failure outside the original 25-control
matrix. A committed leaf runner introduced a new external fixture check. The old
controller published a receipt for that new version; changing the fixture then
incorrectly inherited exit 0, while an actual OFF execution returned exit 1.
Matching a newly committed fingerprint did not establish its transitive closure.
This invalidates any claim that arbitrary future committed leaf revisions were
already safe, despite the original audited unchanged-leaf full comparison.

The controller now pins the seven explicitly audited source/driver/runner Git
blobs. Unknown committed leaf versions RUN without reusable receipts. Updating
eligibility requires a reviewed closure and changed controller, invalidating
earlier receipts. The exact reproducer on old head
`9bb84ef31dd001cd9e14480c2c2767b9acf7e410` observed unsafe inheritance; on hardened
head `8547008cae267ef3892ce938a04e9e9ee33f8de3` it selected RUN and exposed exit 1,
equal to OFF. These are executed controls, not hypothetical assertions.

The enlarged 27-control matrix completed every scientific assertion on the
hardened head, but its final disposable-checkout cleanup failed with exit 128
because an untracked trial fixture remained. That harness exit is not PASS.
Cleanup now retains an inventory and removes only its own exact disposable
worktree. A fresh terminal matrix and a same-candidate full trial are required
before attributing full qualification to the hardened controller. The fresh
27-control matrix subsequently ended with terminal exit 0 on
`623b82a79f874db56b9f975187f7bc826ae6745f`; its cleanup inventory was empty.
That candidate's full trial was subsequently interrupted as described below. Review/matrix original logs,
authenticated receipts and old/new defect reproductions are archived in
`integration/f-ci/evidence/F-CI_RESUME_REVIEW_20261012.tar.gz.b64`, decoded SHA256
`a833a1d469d012da78dc22683e388e5cb468756999427eaae603c3844524c2e7`.
Earlier full
logs and measurements below remain evidence for their recorded old candidate.

Further review actually reproduced the same defect through an exported shell
`cmp` function: its unchanged environment string referenced a changing fixture.
On `623b82a79f874db56b9f975187f7bc826ae6745f`, RESUME inherited exit 0 while OFF
returned 1. That candidate's fresh full OFF baseline completed at
2026-10-12T20:52:42.649483Z, exit 0, wall 2766.421982 s. Its controlled prefix
completed with expected outer exit 1 in 10.347934 s; both subsequent leaf
inheritances were genuine for that no-function profile. The following full
RESUME was deliberately interrupted through the execution session with exit 130
when the additional defect was confirmed. Its terminal scientific status remains
UNKNOWN, not PASS. Direct cross-session process-group signalling was unavailable;
the supported session interrupt succeeded and no scientific child remained.

The new hardening rejects exported functions in the controller and routes the
caller away from an overridable Python function. It closes linker-script and
Python shared-library dependencies, rejects text helper wrappers, binds a reviewed
complete tool/runtime fingerprint, and rejects implicit source-module prefixes.
Eligible executions use private empty cwd isolation; logs record the actual
absolute command and removed private cwd. Deeply nested corrupt JSON also falls
back to RUN. During that review the controller was not fully qualified: its runtime
profile initially remained PENDING_REVIEW, preventing inheritance during review.
Read-only inspection on `45cac22798902c8c4b4a02fd40d5357d1e125b82` then captured
identical complete profiles for both leaves: 378 tool/file entries, including 48
loaded bytecode files, linked-library/script inputs, file types/modes/ownership,
interpreter flags/principal and CPU model/ISA/microcode identities. Manifest
stdout SHA256 is `5af7b0d6021f1cd1bfebe3834793ca1b70525f714aba27172d6d933ec3114594`;
reviewed fingerprint is `16867dd80199fc0b49cd72386d4f557e07e45bbb4989484b3f77306f57c4e470`.
The Python executable is linked without a separate libpython dependency in this
actual profile; its own bytes and ELF dependencies are included. Inspection
produced no scientific PASS, receipt or inheritance. The pin now enables only
this reviewed profile. Fresh full qualification subsequently completed above.

The first positive inheritance trial on the pinned profile selected an extra
RUN: CPU tuples became JSON lists when receipts were decoded. This representation
error was fail-closed, not false inheritance. Explicit JSON-compatible CPU arrays
fixed it without changing the reviewed fingerprint. The complete 33-control
matrix then ended with exit 0 on `dd3c823b14ab1e49b1604482de5214ea1f77879a`,
including the exported Python-launcher override, malformed nested JSON and a
real corrupt source-directory generated module (RUN, compiler exit 1). Removing
that unqualified module restored valid inheritance of an earlier unchanged
isolated execution. The exported-fixture reproducer on this controller returned
RUN/exit 1 equal to OFF. The same-candidate complete OFF/interruption/RESUME
experiment subsequently completed with both full exit codes 0, as recorded above.
All these original manifests, controls and failed/unknown attempts are preserved
in `F-CI_RESUME_HARDENED_REVIEW_20261012.tar.gz.b64`, decoded SHA256
`b75bd7a0139dabab55577f28ef31a373a99e78e7e255f7d3aa380560034d155a`.

## Earlier candidate: what was demonstrated

The original full moving F-CI ended with exit 0 in OFF. After a real nonzero
controlled interruption, RESUME authenticated and inherited exactly two complete
frost O0/O2 leaves. The complete resumed moving F-CI also ended with exit 0.
Every other original runner call remained in the same order and executed.
No production physics, reference, assertion, tolerance or original scientific
runner body was changed. Full Richards, mass, transaction/state ownership,
accept/retry/rollback, restart and coupling preservation remain the original
moving gate's acceptance claims, not new or wider physical capability admission.

The focused safety matrix completed 25 actual controls. All final negative
controls selected RUN; none incorrectly inherited. These include source and
literal reference-oracle bytes, runner/control/arguments, FFLAGS/environment,
actual compiler-specs mutation, missing identity/status/log, damaged evidence,
forged manifest and mid-group interruption. Between-group interruption preserves
valid terminal authority. Real private build directories from interrupted work
were deleted before valid inheritance and an independent downstream compilation.
No selected leaf requires surviving generated inputs or build outputs. Missing
necessary generated/shared state is therefore not claimed tested for a reusable
producer-consumer group: those groups remain unqualified and RUN.

The original strict stdout comparison returned nonzero despite both scientific
gates passing. Exactly nine differences were private build identifiers: one
mktemp nonce and eight executable paths containing a process ID. All original
numeric values, case/optimization identities and gate text are byte-identical.
`tests/fci/compare_resume_trial.py` normalizes only these anchored complete line
forms, retains opt/subcase suffixes, and rejects changes to a number, opt or case.
The raw comparison failure, original outputs and explicit path adjudication are
retained. This is diagnostic-path normalization, not numerical tolerance change.
Normalized SHA256 for both complete original scientific streams:
`df4ee0b0856f55f09db7372d8b80d2296f55252bb8f4d1aa1225e7c873604a21`.

## Earlier candidate: measured work and costs

These measurements apply only to `aef26ee85ddb58195f005169985dd52fc0bd9545`.
The final closed-profile measurements above supersede them for present use.

| Quantity | Observed result | Scope/limit |
| --- | ---: | --- |
| OFF baseline calendar duration | 3001.542764 s | Terminal full moving F-CI exit 0 |
| RESUME calendar duration | 2786.124132 s | Terminal full moving F-CI exit 0 |
| Controlled completed prefix | 14.244331 s | Intentional outer exit 1, never full PASS |
| Observed whole-run difference | 215.418632 s | Not causally attributable to inheritance |
| Original top-level calls | 26 baseline; 24 resumed | Includes four pure-verifier calls in each run |
| Scientific top-level invocations | 22 baseline; 20 resumed | Two additional groups were inherited; nested calls not separately counted |
| Actually inherited groups | 2 | frost-invalid and frost-independent |
| Scientific compile/link commands avoided | 8 | Six plus two, from original executed loops and native exec compiler; not source-unit count |
| Repeated compilation in inherited leaves | 0 | Verified inheritance branches execute no child science command |
| Executed wall time of skipped leaves | 1.689433 s | Measured real prefix executions, includes execution/log I/O; not pure CPU time |
| RESUME evidence/input verification | 3.639393 s | Closure hashing, tool identification and authenticated evidence verification together |
| Initial prefix input verification | 2.019110 s | Before actual leaf execution |
| Atomic receipt write overhead | 0.002340 s | Two measured fsync/replace publications only |
| Post-run closure revalidation overhead | UNKNOWN | Not separately timed; do not hide it in the write number |
| Pure compilation CPU time avoided | UNKNOWN | No independent CPU accounting |
| Total compilation count of unqualified gates | UNKNOWN | Not instrumented; those gates all ran |
| Build-object cache enabled by resume | No | Original gates compile privately; this mechanism reuses complete evidence |
| Filesystem-cache/host-load contribution | UNKNOWN | No controlled cold/warm-host intervention |
| Full same-candidate experiment repetitions | 1 | Insufficient for a general throughput claim |

All original remaining top-level commands and arguments are equal in sequence.
The start of RESUME follows the interrupted prefix immediately; the resumed
calendar duration is the measured recovery execution cost. The initial selected
leaf verification costs are reported above rather than inventing a separate
pure recovery/setup time. Complete baseline/prefix/resume commands, UTC controls,
SHA256 output identities, execution decisions and signed receipts are archived.

The selected groups are too short to prove useful net calendar savings:
verification alone exceeded their measured avoided execution time. The observed
215-second shorter whole run cannot be called a cache speedup when only 1.69
seconds of leaf execution were actually omitted. Warm filesystem effects,
external host load and other execution variation remain unquantified. The result
proves safe bounded reuse and eight avoided compile/link commands. It does not
prove that this initial granularity speeds up migration. Keep OFF as the default;
larger groups require their own complete input/output closure and qualification.

FFLAGS is not used by these hardcoded leaf scripts, but the conservative complete
environment fingerprint still selected RUN after its change. This is an observed
extra RUN, not an independently necessary scientific requalification. More
volatile unused environment changes may similarly force RUN. No broad environment
selector is inferred safe from this experiment.

## Failed and unknown attempts retained

The first full OFF attempt failed in 10.362399 s because a historical F-CI93
commit was absent from the single-branch clone. Required immutable object IDs
were fetched, then the previously qualified local Git object store was recovered
read-only; connectivity checking completed. This is not a scientific regression.
A second OFF attempt was deliberately interrupted before freezing the hardened
controller; without terminal status it remains UNKNOWN. Neither is counted PASS.

Earlier small trial failures exposed a stale compiler-mutation fixture and an
incorrect assumption that private directories must be empty after SIGTERM. Those
trial designs were repaired and the entire final matrix rerun. One earlier
post-execution closure rejection was conservatively nonterminal; its exact cause
remains UNKNOWN, and its partial outputs are retained. The final unchanged-input
positive controls passed. The first full stdout comparison also failed until the
nine actual private-path differences were explicitly adjudicated above. No red
result was relabelled as an unexecuted successful test.

## Recovery and admission boundary

Recovery authority is `integration/f-ci/F-CI_RESUME_STATUS.json`. The original
canonical base is `a1b4bb432827149872445161fbcb775bba5c4cb1`; PR1211 and the
PR1216 daily-demand admission were reconciled. The historical 3327.080030-second
preservation evidence remains unchanged and is not this experiment's baseline.
All 2440 archived historical execution inputs were checked; only the moving
runner changed. Original source/reference/test/tooling input identities elsewhere
matched. A matching historical head alone was not used for new inheritance.

To replay, check out the actual execution head, provision the same compiler
capsule and environment, and run `tests/fci/run_resume_full_trial.py` with a new
output path, separately retained private key and explicit capsule directories.
The comparator can independently evaluate the archived baseline/resumed outputs
using `python tests/fci/compare_resume_trial.py <decoded-evidence-directory>`.
A fresh checkout/path, changed environment or lost signing key may conservatively
RUN instead of reuse. Journaling requires a private durable filesystem supplied
by the operator; this test demonstrates process interruption, not a cloud-disk
loss or hostile-OS attestation. The signing key is deliberately not published.

The bounded scientific experiment is complete. At scientific closeout the
separate owning decision was pending. On 13 October 2026 at 06:34:29 Europe/Amsterdam,
the user answered “Ik bevestig” to the explicit question whether, as central REGIE,
they accepted the proposed bounded F-CI/VQ decision and authorized PR1217 admission
after final checks. This is the recorded user/REGIE disposition, not an invented
GitHub review submission or external independent audit.

Accepted scope: exactly the two audited no-output frost groups and reviewed
runtime profile, opt-in and OFF by default; all other groups and guards RUN.
The owner accepts the documented storage/key/trust limits and absence of net
speedup. New source/runtime/group eligibility requires closure review and
requalification. Admission still requires live ref/check reconciliation and
unchanged relevant tested inputs; its execution and canonical verification are
recorded in `integration/f-ci/F-CI_RESUME_STATUS.json`. No production,
broader-profile, default-enablement or generalized performance claim is admitted.

Canonical admission executed through the normal expected-head guarded PR merge,
without protected-check override: `f9775af0df771d870ca1bd0018e0beaa795404b9`.
Parents are the pinned canonical base and admitted head
`c8c5c82a0c892fe2f3255de112ac7d6ff9d53c35`; tree
`29bc7851ccba7a1d6553bb65964bf955cb93c1d6` is exactly the approved postimage.
Production, reference, controller and outer-runner inputs are byte-identical to
the actual scientific candidate. Four automatic push runs started; at the first
receipt F-CI51P and F-CI58P had succeeded, while F-CI canonical and groundwater
closeout remained RUNNING. Their terminal outcomes are recorded in the status;
in-progress checks are not PASS. No new workflow was dispatched.

Terminal closeout: all four push workflows completed with conclusion `success`.
F-CI run `38347529837` completed all 15 jobs successfully, including moving-current
preservation job `115132748719`. Groundwater closeout `38347529889`, F-CI51P
`38347530005` and F-CI58P `38347529851` also succeeded. Complete job identifiers
and UTC start/end metadata are retained in the existing status record. These
are independent canonical post-merge checks, not additional same-environment
performance samples. Documentary receipt commits change no tested scientific
input; qualification inheritance is limited to that verified unchanged closure.
