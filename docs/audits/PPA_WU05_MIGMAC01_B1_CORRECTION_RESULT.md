# MIGMAC01 bounded B1 correction result
Date: 2026-10-02
Status: IMPLEMENTED_PERSISTED_LOCAL_TESTED_PENDING_TARGETED_QUALIFICATION
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
