# F-CI bounded safe resume

Status: implemented opt-in candidate, not canonically admitted. Baseline canonical
`a1b4bb432827149872445161fbcb775bba5c4cb1`; qualification and recovery authority:
`integration/f-ci/F-CI_RESUME_STATUS.json`. This changes qualification execution,
not production physics, assertions, tolerance or immutable evidence. F-CI/VQ
admission remains required. OFF remains the default original command execution.

## Diagnosis and execution graph

The original moving runner has guards interleaved with conditional science calls.
Git ancestry, exact source pins and owner/evidence verifiers choose scientific
successors. PASS lines near the final runner tail are summaries of preceding
work, not independently cacheable groups. The observation under
`integration/f-ci/evidence/F-CI_RESUME_EXECUTION_GRAPH_20261012.json` records 84
statically named runner files and 142 callsites, including non-active branches.
Exact callsite text and source identities preserve conditional navigation. It is
not a new mandatory register or an automatic dependency analyser. Dynamic paths,
inline generators and deeper compile closures remain the original runners' work.

| Class | Current treatment |
| --- | --- |
| Pure guards, ancestry, source/evidence identity checks | Always execute; no inherited guard PASS |
| Independently qualified no-output leaves | Two explicit frost O0/O2 groups below |
| Shared build/temporary state | RUN; for example fixed `mc-heat01-local` directories are not isolated cache candidates |
| Joint order/state/producer-consumer compositions | RUN as their complete original subrunner, no interior splitting |
| Other conditional routes or uncertain input/output closure | RUN; no eligibility inferred from a filename or source imports |

Only `frost-invalid` and `frost-independent` are eligible. Both compile the same
single self-contained frost module, with no `use` dependency on another SWAP
module. `frost-invalid` compiles three independent original test drivers at O0
and O2 (six compiler invocations). `frost-independent` compiles its original
nonfinite/bit-preservation oracle at O0/O2 (two invocations). The literal driver
bytes include the reference expectations. There is no external fixture or
persistent generated-input requirement for these two leaves.

Their direct closure is the source module, exact leaf runner and test drivers.
Their transitive control closure includes the moving runner and resume controller,
Python interpreter/loaded modules, selected shell tools, complete declared GCC
capsules, actual compiler/frontend, specs, linker/startup/archive inputs and
selected runtime libraries/loader. SHA256 plus Git blobs bind working and
committed inputs; commands and arguments must equal the explicit allowlist.
Compiler, environment and platform identities are part of equality. Environment
values are hashed rather than publishing potentially secret values.

Eligibility additionally pins the seven audited leaf Git blobs in the controller.
A newly committed source/driver/runner version is not automatically qualified:
it might introduce an external include, fixture or output dependency. Such a
version always RUNs without publishing a reusable receipt. Updating these pins
requires closure review and requalification; the changed controller invalidates
all earlier receipts. The continuation review found and closed this distinction
between identity equality and eligibility. Earlier full experiments tested the
pre-hardening controller; their exact execution SHA remains unchanged.

Eligible executions additionally use a private empty cwd and the actual absolute
leaf command, recorded in the authenticated receipt. This avoids implicit GNU
module lookup in the caller's cwd. Source-directory `.mod`/`.smod` prefixes are
unqualified; no imported generated module state may silently affect the closure.
Linker-script references and the Python interpreter's shared library are included.
Only the reviewed full tool/runtime fingerprint may produce receipts; a new
compiler/runtime/profile must be reviewed and qualified before updating that
controller pin. Unknown profiles RUN without receipts even after successful tests.

Each leaf owns its `mktemp` directory and removes it on EXIT. It exports only
stdout/stderr. No later gate reads its `.mod`, `.o` or executable. Required
persistent outputs are therefore empty; the complete signed transcript is the
scientific evidence. This output-dependency finding is specific to these two
leaves. Missing necessary logs forces RUN. Deleting disposable private build
state does not invalidate this qualified no-output contract. Such deletion would
force RUN for a group with an unmaterialized required output; those groups are
not eligible here.

## RUN/INHERIT and trust

OFF executes the original commands directly, without requiring a store, key or
manifest. SHADOW verifies RUN/INHERIT but executes both original science groups.
RESUME replays authenticated complete original evidence only after successful
identity and terminal-status verification. Every other call is unchanged RUN.
The caller's original scientific marker checks and final gates remain intact.
Unknown mode in the moving runner fails; no selector prints fabricated science.

A receipt requires start/end UTC, exit 0, unchanged start/end input closure,
complete log byte count/SHA256, original terminal marker and no required outputs
or shared state. It is authenticated with HMAC-SHA256 using a separately retained
private 32-byte key. Editing a manifest and recomputing an ordinary self-hash
cannot legitimize evidence. The controller's own committed and working bytes are
bound into the receipt. A control revision invalidates old receipts. Logs are
verified into a single byte buffer and that verified buffer is replayed.

Unknown/missing/dirty input, command/argument mismatch, compiler/flags/environment
change, missing capsule identity, RUNNING/nonterminal/failed status, corrupt
receipt or log and missing output all yield RUN. Shell startup, preload, external
compiler search and Python search overrides are unqualified and force RUN even
if their string values have not changed: their external contents are not assumed
closed. Native GNU compilers and the bounded simple absolute `exec` wrapper form
are supported; other compiler wrappers are unqualified.

Exported shell functions are unqualified, including overrides of the Python
launcher itself. The caller uses a native command lookup and routes exported
functions directly to RUN without the selection controller; direct controller
usage also rejects them. Text helper wrappers, capsule-directory symlinks and
unverifiable ELF dependency graphs cannot produce reusable receipts.

The trust boundary is an exclusive qualification checkout, a controlled toolchain
and a private key retained outside the writable checkpoint store. An adversary
who can change the running controller or read the signing key has compromised
that execution authority; a checksum cannot fix that. This is not an attestation
against a malicious OS or a hostile same-UID signing authority. Receipt edits
without the key, interrupted writes and ordinary corruption are checked. Protect
and retain the key separately; losing it safely causes RUN. Never publish it.

The store must be an absolute private non-symlink path on storage provisioned to
survive interruption. Filesystem `fsync` alone is not cloud persistence. Receipt
writes use a same-directory temporary file, file fsync, atomic replace and parent
fsync. A per-group exclusive lock spans verification, execution and publication.
The previous terminal receipt is invalidated with RUNNING before a new SHADOW/RUN
starts. Mid-group termination forwards signals to the child's process group and
cannot publish PASS. Archives and versioned status are stored in the existing
F-CI evidence hierarchy, not a second administrative registry.

## Usage and recovery

Use an exclusive checkout at the qualified candidate. Provision private durable
storage and create a 32-byte random key with mode 0600 outside the receipt store.
The controller does not create or silently rotate keys. For example:

```bash
export FCI_RESUME_KEY=/durable/private/fci-signing-key
export FCI_RESUME_STORE=/durable/private/fci-receipts
export FCI_RESUME_TOOLCHAIN_DIRS=/absolute/gnu-capsule:/usr/lib/gcc/x86_64-linux-gnu/13
export FCI_RESUME_MODE=SHADOW
bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh
export FCI_RESUME_MODE=RESUME
bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh
```

Set `FCI_RESUME_MODE=OFF` (or unset it) for the original full runner. All compiler
paths and toolchain directory bytes must be retained unchanged. Directory
identity is conservative: an unrelated new file inside a capsule also gives RUN.
Toolchain environment changes must never be explained away as equivalent.

For the controlled interruption test only, `FCI_RESUME_STOP_AFTER=frost-independent`
returns 75 after publishing that completed group. The parent retains its original
failure handling, so the full runner exits nonzero and cannot claim full PASS.
Unset the variable before RESUME. Completed receipts can then be inherited;
RUNNING or unverified groups execute. Recovery does not require surviving builds.

Run the reproducible small safety trial with the actual compiler on PATH:

```bash
python tests/fci/run_resume_safety.py --output /absolute/new-trial-directory \
  --toolchain-dirs "$FCI_RESUME_TOOLCHAIN_DIRS"
```

The trial creates a detached checkout, real O0/O2 executions, source/oracle/runner/
control/environment/toolchain mutations, authenticated-manifest/log corruption,
mid-run and between-group interruption, private-build deletion and an independent
downstream compilation. It preserves original transcripts and exact timings.
It requires a new output directory and writable first toolchain capsule for one
bounded add/remove mutation. Do not run capsule mutation concurrently with science.

## Measurement and limitations

The immutable historical full preservation archive decodes to SHA256
`644300a5db9358dd2fc46b59b946626aa49d80729bc14b6c23c10579bdd6531c`.
Its 2440 archived execution inputs were checked again: only the moving runner
changed; every other archived input matched. The original archive and UNKNOWN
interrupted attempt remain untouched. It is a historical 3327.080030-second
baseline, not automatic qualification of this new runner/control mechanism.

This first implementation can avoid eight scientific compiler invocations plus
their executions after interruption. Verification itself consumes time. Count
compiler invocations separately from compiled source units and links. No build
cache is enabled by this mechanism. Report successful OFF baseline, controlled
prefix, RESUME, verified log/results equality, per-group decision/verification/
checkpoint timings and unknown costs through the versioned result authority.
One ordered run cannot prove a general speedup; two short leaves cannot support
a broad migration-speed claim. Broader group qualification is separate work.

The completed full experiment, raw-comparison adjudication and measured limits
are recorded in [F-CI resume result](../audits/FCI_RESUME_RESULT_20261012.md).
The final closed-profile candidate is `dd3c823b14ab1e49b1604482de5214ea1f77879a`:
33 focused controls, full OFF and full RESUME completed successfully. Recompute
the raw evidence measurements with `tests/fci/summarize_resume_trial.py`; optional
`--key /private/retained-key` verifies receipt authentication without publishing
the key. Missing key reports authentication UNKNOWN and cannot authorize reuse.
The two inherited leaves avoided eight compile/link commands and 1.409290 seconds
of measured group execution, while verification cost 1.599199 seconds. There is
no demonstrated net speedup. Canonical admission remains with central REGIE after
the owning F-CI/VQ disposition; OFF remains default.
