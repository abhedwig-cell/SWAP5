# PPA-MICRO02 standalone checkpoint

The [draft PR #1071](https://github.com/abhedwig-cell/SWAP5/pull/1071)
contains a typed call-local de Willigen uptake evaluator and a real B1.10 MvG
sampling adapter for the already admitted MICRO01 matric-flux table. It is
not connected to the accepted runtime root sink.

The exact B1.11 nonlinear routine was compiled as a literal oracle with only
public test access and the disclosed MICRO01 dry-table correction. The
direct-entry harness explicitly sets the module `iMicro=1` normally set by
`do_RWU_micro`. Run 37420361646 passed O0/O2-identical output for four
constant-conductivity model/stress cases and one heterogeneous-head case,
with the literal source's three convergence/closure checks true and typed
per-node flux differences below 2e-5 cm/d. The same run exercised a real
MvG-owned table sample and uptake smoke, as well as input rejection and
repeatability. Its ZIP digest is
`38cb1b5062cc544a0da7d25b312fb0b6bea661f6bea5162700dacb51a5fc4166`.
The immutable [evidence](evidence/PPA_MICRO02_STANDALONE_SOURCE_FINAL_REPLAY.json.gz)
has the exact source and test hashes, patch list, outputs and executed
PR-merge postimage. The qualified source hashes match the proposed branch
head; the merge execution SHA itself differs because GitHub tests PR merge
commits.

Early source-oracle attempts omitted that `iMicro` module setting. Their
false signed/closure findings were retracted and remain recorded as negative
*harness* evidence in `integration/audits/PPA_MICRO02_STATUS.json`. An attempted
extra final `myFun` evaluation was removed. The B1.11 nonlinear source is
otherwise unchanged in the successful comparison.

This result does not admit MICRO production, a heterogeneous-horizon
equivalence claim, hydraulic lift, de Jong van Lier, or salt/oxygen/frost
runtime composition. The remaining work is an explicit horizon binding and
one accepted root sink through trial/reject, water mass and committed restart;
signed hydraulic redistribution requires a different water-source contract.
The frozen Status-A denominator and separate Jarvis/Walsum admission are
unchanged.
