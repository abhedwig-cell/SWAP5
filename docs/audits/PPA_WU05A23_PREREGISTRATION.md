# PPA-WU05-A23 preregistration — RFM whole-column candidate ledger

Date: 2026-10-01
Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS
Baseline: integration/f-ci-canonical@e9f210a41bca5bf9c6b9118f91a2be020e76b26f

## Purpose
Compose the admitted RFM receipts into one candidate-only whole-column ownership ledger before any live-runtime guard is removed.

## Leading interval semantics
A15 partitions effective surface supply into matrix and preferential rates.
A17 partitions preferential rate into terminating IC and persistent MB rates.
After multiplication by dt exactly once:

- matrix input is external surface input to the existing matrix solver;
- IC input enters endpoint fast storage;
- A22A releases some endpoint storage internally to matrix;
- remaining endpoint water is fast storage end;
- MB input is resolved in the same interval by A22B into internal wall-to-matrix transfer plus external/deep RFM receipt;
- leading A23 MB storage end is therefore zero.

A19's MB storage field remains a valid generic carrier but is not populated by the leading A23 fast-through MB route.

## Whole-column mass identity

Let:
  W = effective surface input over dt
  M = matrix surface input
  I = IC preferential input
  B = MB preferential input
  Xic = IC endpoint -> matrix transfer
  Xmb = MB wall -> matrix transfer
  D = MB deep receipt
  Sf0/Sf1 = endpoint fast storage start/end

Then:
  W = M + I + B
  I + Sf0 = Xic + Sf1
  B = Xmb + D

and therefore:
  W + Sf0 = M + Xic + Xmb + D + Sf1

Internal transfers Xic/Xmb must not appear as external whole-column losses.

## Qualification
Use explicit synthetic receipts and prove:
- each component identity;
- aggregate identity <= 1e-12 cm;
- replay bit identity;
- mismatch in any upstream receipt fails closed;
- nonzero leading MB end storage fails closed.

No matrix solve, runtime mutation or guard removal occurs in A23.
