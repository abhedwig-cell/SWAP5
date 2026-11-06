# Complete-generation publication contract

Status: private native evidence is canonical at PR1578 (`8da740df7`).
The exact production successor is implemented in PR1579; canonical production
admission remains pending its complete source/build qualification.
Authority: GENERATION_PUBLICATION_PREREGISTRATION_20261106.json.

A complete physical/diagnostic/history generation is the single persistent
authority. Its caller publishes staged in-memory owners only after the writer
reports success. Every failure reported by this writer must therefore precede
replacement of the authoritative name. A successful write means a closed,
flushed complete file and atomic same-directory replacement, exactly the
existing POSIX generation contract. It introduces no directory-durability claim.
CSV remains a separate observer with its existing post-generation failure rule.

The existing restart publisher has a different established contract: directory
synchronization may fail at stage6 after replacement. Its public entry points,
UTF-8 path behavior on Windows, stage outcomes and directory synchronization are
preserved. That post-publication failure result cannot be silently mapped onto
the generation writer's precommit-only interface.

The private candidate shares the platform implementation with an explicit
internal directory-sync policy. Existing restart entries select the established
policy. A separate generation entry selects file flush, close and atomic
replacement with no fallible step after replacement. It preserves sibling-path
validation and excludes copy/delete fallbacks. Windows retains bounded I/O-only
replacement retries; solver and physical retry policy are untouched.

The selected Windows Fortran generation surface is ASCII paths. The new low-level
generation entry rejects other Windows path bytes before publication; POSIX
native-byte paths and the existing restart UTF-8 contract retain their scope.
Broader Fortran path encoding requires separate native evidence.

Required qualification includes actual old/new C API and CRC behavior at O0/O2;
existing stage2..6 restart outcomes; new stage2..5 precommit failures; complete
original model assertions, native state/CRC/history/fresh reconstruction and
live-authority preservation on both supported platforms. Windows process tests
use real named events at the publication seam and actual process termination;
they make no POSIX signal claim. Test-only fault and scheduling interception is
outside production code and has no production environment switch.

The Windows original recipes retain all physical/native/invalid assertions.
Their POSIX resource and process hooks are explicitly separated. Actual PE stack
reservation is verified; actual compiler response files avoid CreateProcess206
without changing numerical flags. Completed compiler/source cohorts may be
reused only with exact provenance and preserved original failures. Canonical
admission requires complete current/predecessor qualification and adjudication.

The retained local Windows private execution now passes all five original native
recipes at O0/O2, with 14 actual links and 2126 pinned provider/module artifacts.
Independent checks validate 24 complete positive generation files and nested
checksums. Twenty actual public-writer precommit failures preserve authority;
eight real process terminations on the two publication sides reconstruct the
expected complete old/new authority. Raw source, compiler response, PE stack and
data controls are retained losslessly in the dated Windows publication capsule.
These are private runtime results, with production unchanged. Actual POSIX
O0/O2 execution of the same five original recipes also passes, including original
SIGKILL controls before/after publication and unchanged restart stage6 behavior.
All 24 selected positive generation files are byte-identical across the two
measured platforms. Independent source/object/data remeasurement and four
corrupted-evidence controls pass. Final current/canonical qualification remains
a separate requirement. The exact original POSIX artifact ZIP and every Windows
cohort member are retained losslessly in dated publication evidence capsules.

Production integration uses exactly the four measured full source postimages,
with a strict current source/record gate and the entire unmodified private-base
admission in an isolated predecessor view. The existing old guards are unchanged.
Sixteen malformed-scope controls cover path/scope expansion, reported-failure
semantics, restart stage6, missing evidence, changed gates and extra production
paths. Real solute builders now recognize both native publisher bindings.

The HIST build records the native C support object and keeps the Fortran driver
last, allowing original follow-on CSV/joint/saved recipes to inherit the complete
provider set. The original SWP-reader qualifier likewise takes objects from the
actual compile ledger, retaining non-numbered native support and excluding
exactly the application main. It pins every reused object. Numerical flags,
physical assertions, restart checks and refusal controls are unchanged. A fresh
current-tree O0/O2 five-recipe execution is explicitly selected to qualify this
delivery path; a component C probe cannot detect omitted inherited link objects.

The original Windows CSV writer fails its unchanged public assertion. A focused
native UCRT measurement isolates `rename` returning EEXIST when the target name
already exists, including when the complete CSV bytes are identical. The new
private publisher passes actual replacement. The original failure is retained;
unexecuted later original Windows recipes are not labelled passed.
