# VQ-1c3 B1.5p1 targeted correction qualification

**Workstream:** VQ  
**Slice:** VQ-1c3  
**Reference snapshot:** `B1.5p1`  
**Production code changed:** no

## Purpose

VQ-1c1 proved exact B1.5p1 provenance. VQ-1c2 proved deterministic reconstruction, all five corrected-target hashes and two broad B0 -> B1 control edges. VQ-1c3 now deliberately exercises the defect class behind each admitted B1 correction.

The gate type is chosen to match the defect. A portability or language-contract correction is not forced to produce a hydrological output difference when no such difference is expected.

## Source binding

Every targeted reproducer first requires the exact B0 and B1.5p1 source fragment for the correction. The testbank therefore cannot silently drift into a generic Fortran example unrelated to the pinned snapshot.

Reference identities remain:

```text
B0 distribution SHA-256       2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
B0 SWAP.ZIP SHA-256           1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
B1.5p1 source manifest SHA-256 c50da618aef92f99103531390e243144403060b0066e8dc3d827b79085bd9c30
```

Compiler used for the targeted executable evidence:

```text
GNU Fortran (Debian 14.2.0-19) 14.2.0
```

## SWAP-001 — macropore assignment shape

A strict source-bound microreproducer uses the actual `macp=5000`, `numnod=112` mismatch class.

B0:

```text
VlMpDm1Cp = VlMpDmCp(1,1:numnod)
```

fails under `-fcheck=all` with:

```text
Array bound mismatch ... (5000/112)
```

B1.5p1 explicitly clears the destination and copies only `1:numnod`; the reproducer verifies both the active copy and the zeroed tail.

A second gate uses the actual SWAP macropore case shortened only to `1998-01-01..1998-01-02` plus `SWCSV=0` as an output-only runner compatibility choice. With the normal provisional GNU initialization compatibility (`-finit-local-zero`) plus `-fcheck=all`:

```text
B0: VlMpDm1Cp shape mismatch 5000/112 -> rejected
B1: legacy return 100 + swap.ok          -> PASS
```

This directly reproduces the admitted SWAP-001 behavioural difference on the real macropore execution path.

## SWAP-005 — crop-calendar guard order

The defect is Fortran evaluation-order portability: `.AND.` does not guarantee short-circuit evaluation. The source-bound reproducer places a signaling NaN in the first unused crop record and uses `-ffpe-trap=invalid`.

```text
B0 compound expression: SIGFPE
B1 nested i < ifnd guard: normal completion
```

No crop-model equation changes. The expected difference is only that B1 never evaluates the inactive `i+1` record.

## SWAP-006 — meteo crop-loop sentinel

The source-bound reproducer supplies one loaded crop record followed by a signaling-NaN unused entry.

```text
B0 do-while sentinel scan: evaluates unused record -> SIGFPE
B1 do i=1,ifnd:             never leaves loaded records -> normal completion
```

This independently reproduces the hidden initialization dependency described by the audit dossier.

## SWAP-007 — oxygen-stress quotient overflow

This gate uses the full unchanged official grass-growth case and strict floating-point traps.

```text
B0 strict-FPE run:
SIGFPE in oxygenstress call chain
no swap.ok

B1.5p1 strict-FPE run:
return code 100
swap.ok present
swap.err empty
Swap normal completion!
```

VQ-1c2 already established that the ordinary non-trapping grass control output is byte-identical B0/B1 after timestamp normalization. The expected B1 difference is therefore restricted to the unrepresentable Newton quotient path and its existing restart route.

## SWAP-008 — band solver dummy-argument contract

This defect is a language contract error rather than a new numerical method. The actual B0 and B1 `bandec`/`banbks` routines are compiled into the same 3x3 band-system harness.

Both solve:

```text
[4 1 0] [x1]   [1]
[1 4 1] [x2] = [2]
[0 1 3] [x3]   [3]
```

with zero residual at the recorded precision and identical solution output.

The intended difference is the contract:

```text
B0: incoming a/b are consumed despite INTENT(OUT)  -> formally undefined on entry
B1: consumed-and-overwritten a/b use INTENT(INOUT) -> defined contract
```

Numerical equality on this compiler is expected and desirable; demanding a B0 numerical failure would misstate the admitted correction.

## Qualification matrix

| Correction | Targeted gate | B0 observation | B1.5p1 observation | Result |
| --- | --- | --- | --- | --- |
| SWAP-001 | strict shape + full macropore smoke | 5000/112 mismatch | normal completion | PASS |
| SWAP-005 | signaling-NaN guard-order reproducer | SIGFPE | no inactive access | PASS |
| SWAP-006 | signaling-NaN sentinel reproducer | SIGFPE | bounded `1:ifnd` scan | PASS |
| SWAP-007 | full strict-FPE grass run | SIGFPE in oxygen-stress chain | normal completion | PASS |
| SWAP-008 | actual band solver + contract gate | arithmetic works but dummy contract undefined | same arithmetic, defined `INOUT` contract | PASS |

## Oracle decision

Together with VQ-1c1 and VQ-1c2:

```text
B1.5p1 provenance/identity                    PASS
B1.5p1 deterministic reconstruction           PASS
all corrected-target SHA-256 gates            PASS
broad control edges                            PASS
all five admitted correction-triggering gates PASS
```

VQ therefore qualifies B1.5p1 as the **numerical/behavioural corrected-reference oracle** for B2 regression, with two explicit boundaries:

1. this does not imply exhaustive regression coverage of every SWAP 4.3.1 option combination;
2. legacy `.BAL/.BLC` precision remains insufficient for the SWAP5 invariant-13 machine-precision mass gate. B1 can be the behavioural/numerical oracle while hard mass conservation is evaluated independently through the unrounded B2 accounting contract.

## Integration consequence

The reference-line owner may, after this VQ slice is integrated, replace `PENDING_VQ_IDENTITY_GATE` with a status reflecting the completed VQ identity, reconstruction and targeted numerical/behavioural qualification. Historical B1.2-B1.5 snapshots remain immutable failed-provenance audit records.

The next VQ work is no longer B1 repair. It is the B1 -> B2 reference adapter and executable SWAP5 reference qualification, while transaction, generic-time and unrounded mass gates become executable as the B2 interfaces land.
