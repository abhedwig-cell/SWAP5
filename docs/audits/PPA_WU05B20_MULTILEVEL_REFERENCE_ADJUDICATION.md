# B20 multilevel frost/DIVDRA reference adjudication

Baseline is canonical `78acf56f931763d2e1d4924b3dea0742f231d2e8`, production
source `24fda78fd9a38964c16c89d5505b0056185ac410`. B19 remains admitted in its
single-level bounded runtime scope. This audit changes no production code,
solver policy, state, restart, flux owner or coupling semantics.

## Complete native evidence

Full original FrozenBounds plus full original DIVDRA, the B17-corrected DIVDRA
and one isolated geometry-correction candidate were executed over 9216 declared
inputs each at O0/O2. The matrix covers two/three levels, positive and mixed
signed rates, unequal/equal spacing, normal/low-air, separate infiltration
OFF/ON, blocking and the original 1e-6 scalar threshold. No highest-surface or
top-layer projection is included.

Original and B17 each produce 8488 complete outputs and 728 SIGFPE failures per
optimization. Every negative input is isolated and retained; interrupted
processes are not passing qualification runs. The candidate executes all9216
at both optimization levels. Complete outputs and failure case sets are
O0/O2-identical. This is an exhaustive source-process census, not a complete
legacy-model simulation or runtime admission.

## Demonstrated geometry defect and isolated candidate

In separate infiltration, `Lev2Comp` supplies thickness above the infiltration
layer bottom. Paragraph11 then overwrites that thickness with thickness below
groundwater when both boundaries share a cell. The subsequent overlap formula
subtracts a full cell from the wrong two lengths, producing zero or wrong
saturated transmissivity.

For case2305, groundwater is -2.25 cm, frozen bottom -2.5 cm, raw drainage zero
and bottom -0.002 cm/day. The source places the final infiltration-layer bottom
at3 cm in the same compartment as its top at2.5 cm. The correct saturated span
is0.5 cm. The overwrite instead yields `0.5+0.5-1=0`, followed by division by
zero. An actual one-level reproducer also fails at O0/O2 in original/B17 and
executes with the candidate correction.

FROST-DIVDRA-03 removes only this one assignment from the exact B17 postimage,
retaining existing overlap formulas. Exclusive reconstruction verifies parent,
patch occurrence and candidate hashes and rejects wrong-source/occupied-output
and source-overwrite attempts. There are923 affected matrix cases. All8293
unaffected B17 outputs remain byte-exact. The original complete4536-case B17
single-level corpus was freshly executed with the candidate at O0/O2 and its
immutable output remains byte-exact.

The candidate reference is not yet canonically admitted. The initial
double-precision comparison did not qualify the partition: 645 cases exceeded
the unchanged 2e-12 unit-rate partition-comparison screen. The worst unit-rate
difference is5.754858395379259e-11, with actual nodal difference up to
1.4446044360738597e-10 cm/day. These failures are retained, not hidden by a
larger tolerance. The candidate's actual nodal/scalar residual stays below
7.105427357601002e-15 cm/day. Nodal/scalar closure does not erase the distinct
comparison-screen failure. The later exact-input adjudication below resolves
their cause. No runtime mass-budget relaxation follows.

## Separate unresolved signed-transfer rule

Multilevel DIVDRA shares discharge-layer depths through cumulative absolute
flow times spacing. Independent single-level superposition differs by up to
0.015384615384615385 cm/day. Native sorting is not stable at equal effective
spacing; its ordinal tie policy is explicitly bound in the source comparison.

For low air, FrozenBounds first blocks shallow levels and sums survivors.
Above the1e-6 aggregate threshold it scales all survivors by the common
`1+qbot/total`. Below that threshold it replaces only the deepest survivor with
qbot while retaining other levels. This has the following actual consequences:

| Input survivors (cm/day) | Bottom (cm/day) | Final levels (cm/day) | Bottom minus final drainage (cm/day) |
| --- | --- | --- | --- |
| +0.01, -0.01 | -0.002 | +0.01, -0.002 | -0.01 |
| +0.01, -0.0099995 | -0.002 | +0.01, -0.002 | -0.01 |
| +0.01, -0.0099985 | -0.002 | -13.32333333333542, +13.32133483333542 | approximately -0.0000015 |

The exact cancellation case has zero raw net drainage but a nonzero final
net proposal. Just above the threshold, small aggregate drainage amplifies
large opposite per-level proposals and reverses signs. The corrected nodal
distribution still closes against those final scalar proposals. Therefore this
is not evidence of lost water in a runtime ledger. It is an unresolved physical
transfer policy that code parity alone cannot adjudicate.

Before admitting a multilevel runtime, the owner must choose whether to retain
and explicitly bound this legacy signed-transfer policy or authorize a
separately contracted net-preserving replacement. This audit does not silently
change the scalar/bottom rule or classify it as a proven legacy defect.
The geometric overwrite is a demonstrated implementation defect; the signed
transfer is a separate scientific/ownership decision.

## Evidence and recovery

`integration/audits/PPA_WU05B20_REFERENCE_SUMMARY.json` is the bounded summary.
`evidence/PPA_WU05B20_MULTILEVEL_REFERENCE_REPLAY.json.gz` retains all inputs,
complete native outputs, negative receipts, executable/source hashes,
independent-comparison failures and witnesses. SHA256 is
`b9722a11a7684247b90cd34e3c38e27337fbd7a9d36e43888f9893ec8bd6b368`.
The verifier rejects seven deliberately corrupted/inflated evidence records.

Harness negatives also remain explicit in Git history: the first whole-source
FPE, an inappropriate absolute partition screen for amplified rates, a Python
compensated-sum assumption for a native sequential scalar loop, and an incorrect
stable-sort assumption. Final scalar ownership matches native sequential
binary64 reduction; geometric integrations/inversion remain independent.
The partition screen failures remain historical negative evidence.

## Later exact-input geometric adjudication

The precision hypothesis was separately preregistered before implementation.
In the worst prior case 5116, all nonzero flux lies in one compartment; its
exact geometric weight is 1 and the native source publishes that exact rate.
The independent double-precision inverse integral unnecessarily reconstructs
a depth near 4.5 cm and subtracts 4.5 again to obtain a tiny interval in a
1e-10-conductivity compartment, losing relative digits in the comparator.

A separate independent oracle uses exact binary64 inputs converted with
`Decimal.from_float` and 80/100-digit layer integrals and inversion. It passes
all 9216 cases at the original 2e-12 unit-rate screen, resolving all 645 old
screens without any source or tolerance change. Maximum unit-rate error is
2.3180420846515488e-14; maximum absolute nodal error is
1.1063555732896357e-14 cm/day. The 80/100-digit results differ by at most
1.11182e-73 cm/day. Fresh native O0/O2 executions reproduce the prior sealed
candidate output byte-exactly. The geometry-correction reference is now
qualified in this bounded scope; canonical reference admission remains separate.

The old summary/replay retain the historical negative flag. The current
successor authority is `integration/audits/PPA_WU05B20_CURRENT_REVIEW.json`,
with `evidence/PPA_WU05B20_PRECISION_ADJUDICATION.json.gz`. The successor
verifier rejects removing old failures or enlarging the comparison threshold.

## Concrete test-only net-preserving alternative

FROST-MULTILEVEL-NET01 is a separately preregistered scientific policy proposal,
not a demonstrated B1 correction. On low-air mixed-sign survivors only, it
replaces the signed-total transfer multiplier/replacement by
`final_i = raw_i + qbot * abs(raw_i) / sum(abs(raw))`. The separate bottom
proposal remains. This books the imported bottom contribution over absolute
level-rate weights whose sum is 1, so the final drainage sum is raw sum plus
bottom and the raw signed net proposal is retained. It avoids division by a
small signed total. Unmixed/no-flow and normal-air source branches stay literal.

The generated scratch-only full FrozenBounds experiment executes all 9216
inputs at O0/O2 with byte-identical outputs. It alters 1344 mixed cases; all 7872
unaltered controls remain byte-exact to the geometry-corrected source. All 4536
immutable B17 one-level outputs are freshly preserved at O0/O2. Independent
80/100-digit geometry passes the same 2e-12 screen. Maximum altered signed-net
error is 1.2033729096598453e-17 cm/day and maximum nodal/scalar residual is
1.0408340855860843e-17 cm/day, each against 1e-14.

| Retained raw rates (cm/day) | Native final rates (cm/day) | Proposed final rates (cm/day) | Proposed signed net (cm/day) |
| --- | --- | --- | --- |
| +0.01, -0.01 | +0.01, -0.002 | +0.009, -0.011 | approximately 0 |
| +0.01, -0.0099995 | +0.01, -0.002 | +0.008999975, -0.010999475 | -0.0000005 |
| +0.01, -0.0099985 | -13.3233333333, +13.3213348333 | +0.008999925, -0.010998425 | -0.0000015 |

Bottom is -0.002 cm/day in each example. No existing production module or
reference authority is changed by this experiment. Numerical evidence makes
the proposal reviewable; it does not establish that this physical allocation
is the intended legacy model or authorize production admission. The owner must
explicitly accept this SWAP5 policy difference or retain/bound the source rule.
Full multilevel runtime/rejection/restart/application qualification would follow
that decision. This is the remaining shared scientific authority hold.

Production source, B19 qualification and all immutable original/B17 reference
postimages remain unchanged. Aggregate frost migration remains open, with
multilevel qualification and signed-transfer authority held. Snow, external
frost, additional hybrids and phase-change physics are not admitted here.
