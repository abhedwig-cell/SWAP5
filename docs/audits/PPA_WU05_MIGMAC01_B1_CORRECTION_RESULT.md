# MIGMAC01 bounded B1 correction result
Date: 2026-10-02
Status: TARGETED_CORRECTION_QUALIFIED_SOURCE_CAPTURE_VERIFIED_SWAP5_REPLAY_BLOCKED
Correction preregistration: edb6ce307d9b934b967ea1830ebc5ef867e6260c
Baseline: exact B1.11 CALCGWL SHA256 d7649f02bf6cd629cc7eceb1c761a6c38d6f0adf0d0c072c7aaab3af4562f5eb.

The one-line correction starts the perched search at the existing bottom-up
scan's first negative node, excluding the bottom-connected ordinary saturated
zone. No interface, constitutive equation, forcing or tolerance changed.
The full exact source module is retained alongside a hash-checked correction
gate. The gate compiles the actual module with data-only dependency stubs,
not a rewritten groundwater algorithm. Stubs reject unexpected warnings/errors.
Seven independently prescribed carrier cases pass O0/O2 with bounds and strict
FPE checks; original B1.11 fails the first case with false perched 6/6.

A test-case construction error was caught locally: putting the second wet island
at node 1 invokes a separate existing top-boundary convention. The merging
regression was corrected to two interior wet islands (2 and 4–5), with the
prescribed 0.01-cm intervening air volume below the unchanged 0.1-cm criterion.
No physical Andelst input or reference tolerance was changed.

The fixed modified-Andelst case now selects its FIRST chronological positive
accepted covered event at time 35797.643777768819, dt
0.000037037035292963049 day; the previous uncorrected event is not overwritten.
Top=3, cover=2, accepted cover head=0.00068230903875077459 cm.
Covered receipt=0.00000095210882989715793 cm, matrix sink exactly opposite.
Macro closure residual=2.0801435118671108e-16 cm.
Last-rate ordinary/perched carriers are 48 / 1–28, disjoint.

Last-rate h(2)=0.0096182734785161973 cm differs from final accepted h(2).
The recorded legacy integrated receipt is evaluated on that last nonlinear rate,
not exactly on the final head. Final-head B1.11 potential=
0.0000009354133953325103 cm. This is transparent reference iteration lag;
no new parity tolerance or qualification of lagged SWAP5 composition is implied.

Dedicated Actions gate qualifies only the bounded source-carrier correction
and listed regression cases on its exact persisted postimage. Whole-case
corrected-reference admission, SWAP5 active E2E, production parameter contracts,
mass ownership in SWAP5, replay/restart and preservation remain unqualified.
This correction is not relabelled B1.12 or globally admitted B1.
MIGMAC01 remains open; matrix-area and serialized covering-parameter gaps
remain. Status-A denominator and M2 are unchanged.

Qualification completed: run 36970592651, job 110723548647, head
5b4666d1a168b8f73868bfab0d00c8f342ce4fa8, SUCCESS. Full job logs read and exact checkout verified.
Patched full CALCGWL byte SHA256:
37c63446c8e8b0e80ac3f840d1ec636004d69bf7b15492451bde124f206f2834.
The controlled case was rerun after compiling these exact qualified bytes;
capture SHA256 remained ecb3436099a1dd3907c85c6cb74f3cb42f75f1249cd67fdaba8d0ecadc4276ac.

Corrected-source SWAP5 diagnostic completed against persisted head
44baf4a509d9238b7ac9cf16df8d49412b222e3c. New test and runner blobs verified through connector;
92 compiled source dependencies retain their previously verified blobs.
Both O0 and O2 reproduce:
- carrier agreement: ordinary 48, perched 1–28;
- exact constitutive theta reconstruction;
- remaining exact-last-rate exchange difference max
  0.00091392659217592875 cm/day (unresolved; no parity tolerance changed);
- strict ordinary solver RETRY, 64 iterations, largest compartment residual
  2.7351454434665357e-12 cm/day at node 36 versus fixed 1e-12 criterion;
- theta representational quantum at that node = 2.9976023076450086e-12 cm/day;
- scratch integrated residual sum = 2.0142939864728307e-16 cm.
The residual scale is consistent with floating-point quantization, but does not
prove every cause. It is a native-rate acceptance failure, not evidence of a
production integrated mass imbalance. Typed residual availability is FALSE:
printed default zeros are not valid mass evidence.

The active inner-Richards runtime was nevertheless attempted, retaining every
physical process and the original tolerances. It also requests retry (status 3),
with last tentative h(2)=-0.10221739026906902 cm after 64 iterations.
No accepted candidate, covered receipt or accepted closure residual exists.
Returned huge residual values are unavailable sentinels, not physical balances.
Accepted macro origin remains unchanged on both rejection paths.

MIGMAC01 is therefore NOT qualified, preserved, admitted or closed.
No new A9/PERCH20/PERCH21 preservation claim is inferred from this source gate.
Next safe implementation phase needs recorded explicit source matrix-area and
immutable covering-parameter contracts, full ownership propagation, and a
separate strict native-rate precision/rate-attribution repair. Synthetic tuning,
later event selection and tolerance relaxation remain prohibited.

Canonical rechecked at 7a629a10cabb3553ff77474423e6ccac81b29aec; delta from 0d44f019
contains only lower-boundary authority/documents, with no changed production
dependency in this test. All Status-A and M2 exclusions remain unchanged.
