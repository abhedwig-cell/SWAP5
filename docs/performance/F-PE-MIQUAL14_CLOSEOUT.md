# F-PE-MIQUAL14 closeout — serialized manager scale-crossover benchmark

Date: 2026-10-01

Final status:

`QUALIFIED_MIQUAL14_SERIALIZED_SCALE_CROSSOVER`

MIQUAL14 closes positively.

The scale pattern is now explicit:

- N16: manager about 4.0% slower by median wall;
- N32: approximately break-even;
- N64: manager about 1.6% faster by median wall and CPU;
- N64 geometric-mean wall gain about 2.1%;
- deterministic work reduction grows from 18.75% at N16 to 23.44% at N64.

All three geometries remain physically exact in the frozen equilibrium serialized transaction benchmark.

## Strategic conclusion

The moving-interface manager has crossed from “less solver work” to measured end-to-end runtime benefit at N64.

The remaining blocker for a broader production performance claim is not the manager architecture or N64 runtime overhead. It is the absence of a transaction-valid dynamic serialized benchmark inside the current bounded manager envelope.

Further N16 micro-optimization is not justified now.

## Direct successor

The next workunit should focus on deriving and preregistering a dynamic serialized reference workload from already qualified lower-level physics, preferably at N32/N64.

Until that succeeds:

- retain the manager as explicit opt-in;
- retain `LEGACY_NUMERICS` as production default;
- do not generalize the N64 equilibrium speedup to full SWAP or MultiSWAP.
