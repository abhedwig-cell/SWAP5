# Original macropore state: complete bounded daily restart qualified

Status: qualified opt-in successor, PR1653. Base canonical
`a22754decc0ec4e69304d1495c48bae7cdcdabec`. Public builders and previously admitted
full application profiles remain unchanged. Functional coverage is still three
complete applications; the new numerical-policy route is executed through22 on
Windows, with the short state contracts independently qualified on Ubuntu26.04.
Whole481 execution and scientific equivalence of this route remain open.

## Root cause and implementation

Original MACROINTEGRAL declares a local `FrMpWalWetOld` that shadows the module's
identically named saved field. The previous checkpoint serialized the module
field; the actual previous quadrature endpoint remained hidden in the local
array. A restart consequently lost part of the integrated wet wall fractions
used by PEARL/ANIMO even when all physical water receipts and native text matched.
The original local array's large-static cold-zero behaviour is preserved in a
separate explicit `hybrid_integral_wall_previous` array. Its exact original
assignments, arithmetic and ordering are retained; the module's other field is
kept distinct. Same-platform pre-fix coherent-block cold receipts and every old
payload field match exactly on Windows and Linux. Using the already initialized
module field as a replacement would have changed the first quadrature endpoint;
that shortcut was deliberately avoided.

NativeS5MAC006 saves this independent integral history, original cumulative/
intermediate reset flags and explicit original HeadCalc SAVE counters. Original
reset flags fix the previously observed cumulative bookkeeping mismatch.
HeadCalc counters are zero in the prefix; they are not its causal explanation.
The reader refuses older native magic and the unchanged wrapper binds complete
source/build/input identities. No old checkpoint is rebound or filled by guessing
missing history. Both complete native payloads are retained in each accepted
package. New native size:16,122,624bytes; added history uses the original full
array dimensions, including inactive storage.

The larger original nonlinear/macropore block retains task2 rates, task3 Jacobian,
flunsatok caching, backtracking, original convergence criteria and MACROSTATE.
Added macro/pond calendar triggers are removed and the existing daily mass retry
runs from day1. Original equations, forcing and1e-6cm guard remain unchanged.
This is an explicit opt-in numerical policy; no default builder activates it.

## Actual qualification

Original donor physics objects remain O2. O0/O2 below identify the day-owner
kernel; there is no all-donor-O0 or cross-platform bitwise equality claim.

| Check | Windows O0 / O2 | Ubuntu26.04 O0 / O2 |
| --- | --- | --- |
| Fresh1..4 | 3.211 /2.940s | 2.362 /1.332s |
| Own2to4 | 2.793 /2.363s | 1.205 /1.013s |
| External discard/replay and cold3to4 | 7.529 /6.484s | 2.536 /2.530s |
| Complete receipts and result.end/macro.bin on3 and4 | EXACT | EXACT |
| Discard preserves origin, rejects stale proposal and repeats full candidate | EXACT | EXACT |
| Extra cold3to4 complete payload | EXACT | EXACT |
| Pre-fix coherent-block cold records/old fields | EXACT | EXACT |

Maximum independent daily residual in the four-day check is5.965353207744765e-7cm
Windows /5.96535181195129e-7cm Linux. Different platforms are compared to their
own exact controls. Linux owning job43154680629 completed in24.045s for all
builds and checks; every individual model probe has a20s cap. Exact run source:
`3affe302984bbafc2108fb5b52d7ea91d44d5b80`.

The new Windows own history then continued4to22 in14.269s, all18 days accepted,
maximum residual7.810779596036078e-7cm. Day15 encounters1949 mass-step retries.
Own14to16 takes2.323s and reproduces complete physical receipts, retry counts and
both complete native payloads exactly across those retries. The source call
sequence updates the wall integral in MacroIntegral only after accepted SoilWater
state calculation. This supplies a concrete rejected-step window; it does not
qualify universal rollback across untested processes or full scientific equivalence.

## Reproduction and retained failures

Owner:integration/f-ci/ORIGINAL_MACRO_BLOCK_20261112.json. Machine result:
ORIGINAL_MACRO_BLOCK_RESULT_20261112.json. Qualified archive:
original-macro-restart-qualified-evidence.zip, SHA256
4ca71f582b83616182e98c33675c16324d1812637aeb32a570a7933e5e523e27.
It contains original and generated sources, full build/input/provider/compiler/
executable identities, commands, raw logs, native checkpoints and member hashes.
Linux Actions artifact13914684409 ZIP digest
b4840cb7afd435afe7b31c42e7370c70f130e6e70607d9e28aaf7c97ec228cbe
is independently verified before curation. Older v3/v5 failures remain immutable
in original-macro-block-evidence.zip; their failed assertions are not relabelled.
Two Linux setup failures happened before any model ran: frozen bundle and
reference roots must both come from PROOF_INDEX. No input hash or compiler check
was weakened to resolve those path errors.

Extract the preserved platform capsule to `$base`, then run from the repo root:

```powershell
python -B research/hybrid-water01/qualify_original_macro_restart.py --workspace "$base" --output "$probe"
```

The qualifier uses the exact frozen compiler/object/kernel providers, compiles
only the generated owners, runs short real interfaces and compares all native
bytes. Capsules:hybrid-hupsel-windows-20261111.tar.xz SHA256
678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1;
hybrid-hupsel-linux-20261111.tar.xz SHA256
feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde.
Use MSYS GNU16.2 on Windows or the frozen Ubuntu compiler on Linux; exact compiler
and provider checks remain active. The registered manual workflow is
`grass-thermal-production.yml`, input `hybrid_original_macro_restart=true`.
Its input excludes unrelated kim/production jobs.

Next: measure solver versus checkpoint cost from the already owned day22 using
sparse required checkpoints and a short cap, then select the whole481 generic
trajectory only if the measured cost is practical. Preserve whole-period science
criteria and existing references. Do not repeat successful warm prefixes, the
rejected paired-rate policy or provisional-convergence refresh campaigns.
