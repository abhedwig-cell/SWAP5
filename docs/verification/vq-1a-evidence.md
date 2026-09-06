# VQ-1a qualification evidence

**Workstream:** `VQ`  
**Slice:** `VQ-1a`  
**Baseline:** `40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5`  
**Scope:** harness bootstrap and B0 identity only  
**Production physics qualified:** no

## Evidence summary

The VQ-1a bootstrap is intentionally narrower than numerical model qualification. It proves that the verification layer can fail closed on reference identity and that the supplied audit archive is the exact documented B0 artifact.

### B0 distribution identity

Observed external artifact name in the working environment:

```text
SWAP_4.3.1(6).zip
```

The local filename differs from the canonical package name, which is acceptable because identity is controlled by content rather than filename.

Observed and expected identity:

| Check | Expected | Observed | Result |
| --- | --- | --- | --- |
| Distribution size | `8959314` bytes | `8959314` bytes | PASS |
| Distribution SHA-256 | `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` | same | PASS |
| Source archive SHA-256 | `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` | same | PASS |
| Linux executable SHA-256 | `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862` | same | PASS |

Conclusion: the supplied archive is the exact documented B0 distribution.

## Harness unit tests

The initial `tools/vq/reference_identity.py` logic was exercised with three focused tests:

```text
exact identity                    PASS
same size but wrong SHA-256       PASS (fails closed as intended)
missing archive                   PASS (fails closed as intended)
```

Test runner result:

```text
Ran 3 tests
OK
```

The actual supplied B0 archive was then checked through the same verification logic and returned:

```text
qualified_identity = true
size_matches       = true
sha256_matches     = true
```

## B0 execution probe

The exact packaged Linux executable was invoked against the official Hupselbrook example only to establish runner readiness. It did not reach model execution because the current environment lacks the Intel Fortran runtime library `libimf.so`.

Observed loader failure:

```text
error while loading shared libraries: libimf.so: cannot open shared object file
```

Classification: **environment dependency / runner blocker**.

This is not evidence of a SWAP numerical or physical failure. No B0 output from this failed launch is admitted as regression evidence.

## Acceptance status

| Gate | Status |
| --- | --- |
| Exact VQ Git baseline pinned | PASS |
| B0 distribution identity | PASS |
| Identity checker fails closed | PASS |
| B0 numerical smoke run | BLOCKED by runtime dependency |
| B0 water-balance extraction | NOT YET TESTED |
| B1 comparison | NOT AVAILABLE, no formal B1 snapshot |
| B2 comparison | NOT AVAILABLE, no integrated B2 reference entry point |
| Transaction/generic-time qualification | SPECIFIED, NOT YET EXECUTABLE |

## Invariant review

```text
Affected invariants: 7, 8, 9, 10, 13, 25, 26, 29, 30
Expected effect: strengthens qualification discipline; no production behaviour change
Evidence: pinned baseline, cryptographic B0 checks, focused unit tests, explicit blocked-run classification
Open risk: no numerical oracle can be admitted until a reproducible B0 runtime is available
```

## Next safe step

`VQ-1b`: provide a reproducible B0 runner environment or a separately provenance-qualified source build, then run the smallest official smoke cases and add canonical water-balance extraction. Do not change SWAP production physics to make the harness run.
