# Native Grassgrowth disk restart, 2 November 2026

**Status: canonically admitted bounded native I/O**, PR [#1483](https://github.com/abhedwig-cell/SWAP5/pull/1483), merge `bf9982047`. Owning recovery,
test selection and evidence are in
[`integration/dataqual15/STATUS.json`](https://github.com/abhedwig-cell/SWAP5/blob/integration/f-ci-canonical/integration/dataqual15/STATUS.json),
field `native_disk_restart_20261102`. Canonical admission and full original-project
scientific qualification are separate.

## Publication contract

The application closes a complete `S5GRS003` pending stream before publication.
The platform adapter owns file operations only. Physical state, input bytes,
codec fields, solver policy, mass gates and restart acceptance are retained.

On Windows, the adapter uses a writable handle, `FlushFileBuffers`, checked
handle close and `MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH)`. It does not
delete the old checkpoint or fall back to copy/delete. Transient access,
sharing and lock errors receive at most twenty 10 ms waits; persistent errors
remain failed publication. Readers close their snapshot handles promptly and
permit deletion. The old published generation survives pre-replacement failures.
See the Microsoft contracts for
[MoveFileExW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw)
and [FlushFileBuffers](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers).

On POSIX, publication synchronizes the closed pending file, renames it and
synchronizes the actual destination parent directory. Failure after rename is
reported without attempting to roll back a potentially durable name. Native
failure controls cover this distinction.

The same CRC-32 byte contract is implemented with unsigned C arithmetic for
this application. An isolated real-stream reproducer shows a GNU Fortran 16.2
Windows O2 loop-optimization failure in the legacy Fortran routine. O0 and the
diagnostic `-fno-tree-loop-optimize` control return the correct checksum. Final
model builds retain O2; that diagnostic compiler workaround is not used.
Seventeen independent zlib vectors per build check the replacement primitive.
Other consumers of the shared legacy Fortran CRC are outside this repair.

## Reproduce the supported native route

From a clean source checkout with GNU Fortran and GCC on PATH:

```text
python -B tests/dataqual15/test_restart_publication.py --output ../publication-check
python -B tools/solute/build_grass_startup.py --output ../grass-native-O2 --optimization O2 --end 1 --policy retained
python -B tests/dataqual15/qualify_native_disk_restart.py --bundle ../grass-native-O2 --output ../restart-check
```

The builder materializes the pinned original input utilities and builds TTUTIL
when no external input archive is supplied. It records the actual `.exe` name,
source/object/archive identities and C/Fortran flags. The diagnostic builder is
explicitly rebound to the current recipe; its historical seal is retained as
historical evidence, not silently inherited.

## Evidence boundary

Windows checked O0/O2 complete the source-contiguous original segments
1-to-120 and 121-to-367, including the annual crop/root reset. Same-build
117-to-120 and 365-to-367 disk continuations are byte-exact against their
uninterrupted segment. All eleven existing corruption controls pass,
including active LAIEXP compatibility state. Water, crop, profile and endpoint
outputs and physical checkpoint payloads agree exactly between O0 and O2.
The independent water residual over the combined 367 days is at most
`3.795e-14 cm`. This is a bounded platform execution, not another independent
original project or a full 1827-day Windows run.

The Linux preservation workflow executes native publication/error controls and
the real original three-day application with exact 1-to-3 disk continuation at
O0/O2. Its current source-bound run is recorded in the owning status.

Verify the sealed raw dossier without a compiler or execution of archived binaries:

```text
python -B tests/dataqual15/verify_native_restart_evidence.py
```

In a managed Windows sandbox, point `TEMP` and `TMP` at a writable scratch
directory before this extraction-based verification.

These tests qualify same-build native disk restart within their stated original
trajectory. They do not establish cross-platform binary ABI compatibility,
power-loss/hardware-cache or cloud-sync behaviour, whole physical energy closure,
or whole-project scientific equivalence. The original project denominator is
unchanged. Hupsel/Andelst and other POSIX-only publication adapters remain under
their own owners.

## Canonical admission boundary

`verify_native_restart_admission.py` checks the complete current production delta
against exact Git blobs: only the Grassgrowth codec and native I/O adapter may
differ from canonical predecessor `1844fad45`. Unknown, dirty or untracked
production source is rejected. The known build/launcher changes are pinned too.

The unchanged scientific verifiers run in a separate committed preservation
view with exactly the predecessor `src`, `app` and `reference` trees and the
five explicitly restored codec/build/launcher files. The native adapter is absent
there. Old source guards and immutable manifests are not edited or bypassed.
That leg verifies the actual historical 1827/1096-day evidence and retains every
failed scientific gate. Its verdict is explicitly predecessor evidence.

The independent current leg verifies the sealed native 367-day Windows evidence;
fresh Linux publication/restart composition runs on the current source. F-CI
feedback composes these two stated boundaries. The existing mowing, runtime,
stress and same-binary recovery jobs retain their full bodies in the closed
preservation view; the shared physical source tree is identical to current.
Neither leg claims a new current-executable 1827-day run or full moving F-CI.
