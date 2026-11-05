# Complete-generation publication contract

Status: proposed private successor; production source and admission unchanged.
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
