# SWAP5-NOMACRO-CLOSURE01 release workpoint

Baseline: canonical84e297af23b2b6e90c927b958fecb5e24228b975,12November2026.
Development branch: codex/swap5-nomacro-closure01. Proposed, not admitted.

The owner excludes active macropores from the next release. All existing macro
code, evidence and branches are preserved; no new macro calculation is selected.
The public release option rejects original Andelst before compilation instead
of altering its physical input. Existing legacy entry points remain available.

The current implementation generalizes the original-block host's existing
solute/nonmacro process selection and adds the original SaltFarm04dS scenario:
195physical nodes, potato rotation, irrigation, salinity, drainage and original
initial profile,2012–2015 (1461days). The original workbook supplies581events.
The explicit materializer preserves source hashes and numeric/date values;
byte equivalence with the original R preprocessing is NOT established.

Native initial input and host-owned continuation are distinguished by the
reserved restart.end filename. Durable continuation still requires the complete
bound native/auxiliary package. Transaction guards stay1e-10; physical equations,
calculation order and original tolerances are not relaxed. Separate workers
continue to own legacy globals; thread safety is not asserted.

Initial feedback: two materializer/parser failures occurred before model start
(REAL lexical form and omitted TTUTIL column header). Both remain failed input
attempts. Header-corrected O2 cold1–4 completed in1.419s with maximum water
residual5.651035195342047e-13cm. This is preliminary local feedback, not release
qualification. No repeated numerical repair was attempted.

Next deliverable: full SaltFarm1461, exact complete own day continuations across
irrigation/rotation, independent-instance and rejected-state checks, actual
donorO2/kernelO0/O2 controls and affected Grassgrowth/Hupsel preservation, then
one reviewable PR. Model calls are capped; compilation is measured separately.
Do not relabel unchanged historical evidence as freshly executed qualification.

Inherited Grassgrowth1827/Hupsel1096 proofs retain their exact source boundaries
in SWAP5_FUNCTIONAL_CLOSURE and FULL_TRAJECTORY_SCIENTIFIC_DISPOSITION. Their
failed oxygen criteria and underresolved reference families remain visible.
Original conduction/sensible storage observations do not establish full physical
energy with advection; missing energy fluxes are not assigned invented zeros.
External forcing admission remains limited to the existing documented contracts.

## Executed successor at a711d7371

SaltFarm1461 completes under donorO2/kernelO0 and donorO2/kernelO2, in11.634s
and11.922s respectively (full model/controller calls, compilation separate).
Both complete daily ledgers are byte-identical. The maximum independent daily
water residual is1.8597862833091838e-11cm, cumulative signed3.118439194480134e-10cm.
Solute maximum8.099007575701478e-12mg/cm2, cumulative8.772740971773403e-12mg/cm2.
All1461 daily guards stay1e-10; budget-driven timestep retries are zero.
This counts those additional retries only, not every original Newton iteration.

Own2→4,107→110,365→367 and731→733 reproduce complete physical receipts and both
native/auxiliary payloads exactly in BOTH kernel profiles. Interleaved original
instances and refusal after two accepted days preserve the rejected column's
accepted state while the other column advances. The external original-forcing
adapter passes prepare/discard/repeat/accept through day2. This adds no controlled
SaltFarm boundary override and makes no new MODFLOW solver claim.

**Open admission failure: own1459→1461 is not bitwise exact**, in BOTH profiles.
Maximum pressure difference is1.1368683772161603e-13cm; native and auxiliary
endpoint bytes differ. This reproducible failure remains FAIL_EXACT_OWN_RESTART;
the qualification command returns1, even though the daily balances pass. No
tolerance or exact-state assertion has been loosened. Its cause is not yet
established; small magnitude is not proof of complete state ownership.

Current Grassgrowth/Hupsel O0/O2 prefix, exact own restart, independent distinct
instances, malformed-state and rejection checks all pass. Every corresponding
generated donor source, raw continuous/resumed receipt and complete endpoint
payload is byte-identical to the frozen same-platform provider. These bounded
preservation controls do not relabel old full trajectories as newly executed.
The original active-macro CLI request refuses with exit2 before creating output.

Raw proof: `nomacro-saltfarm-windows-20261112.tar.xz`, with every member SHA256
in `NOMACRO_RAW_INDEX_20261112.json`; the archive was reopened and every digest
verified. `NOMACRO_PRESERVATION_20261112.json` retains affected prior/current
comparisons. Windows GNU16.2 donorO2; O0/O2 denotes the actual SWAP5 kernel.
The SaltFarm O2 compile duration is UNKNOWN: an initial proof-resume validation
duration was incorrectly labeled compilation and is explicitly corrected. O0
compilation was10.097s. Full model durations come from the retained EVENTS.json.

Reproduction, with an existing pinned original provider in REFERENCE:

```text
python tools/solute/prepare_saltfarm.py --output NEW_ORIGINAL_CASE
python research/hybrid-water01/qualify_nomacro_saltfarm.py --reference REFERENCE --output NEW_PROOF_O0 --optimization O0
python research/hybrid-water01/qualify_nomacro_saltfarm.py --reference REFERENCE --output NEW_PROOF_O2 --optimization O2
python research/hybrid-water01/qualify_nomacro_saltfarm.py --reference REFERENCE --output EXISTING_PROOF --optimization O2 --resume-proof
python research/hybrid-water01/qualify_generic_hybrid_waterhost.py --no-macro-release --reference REFERENCE --output NEW_CONTROL --project grass --optimization O0
```

Repeat the last command for grass/O2,hupsel/O0,hupsel/O2. The pinned Windows
provider is the unchanged reference/build from the original generic-water proof;
its object/library/compiler/source hashes are recorded in each BUILD.json. The
new SaltFarm case is installed from the versioned materialization when absent;
an existing foreign case is refused. Proof-only resumption verifies current
source/binary/input bindings and existing raw records instead of rerunning1461.

Review status: proposed, merge blocked by exact terminal continuation; Linux
qualification and the additional SaltFarm supported-heat accounting remain open.
Next concrete deliverable: isolate the terminal same-state derived/input-history
dependency with one short1459→1461 comparison; repair only a demonstrated missing
state, then repeat that bounded continuation before selecting any full replay.
No new macropore calculation or implementation is selected.

Published review: https://github.com/abhedwig-cell/SWAP5/pull/1658 (draft, no merge).
Published proof head9dcf823279eb08ac1175e60a68d0e1edddeaf682 and canonical
84e297af23b2b6e90c927b958fecb5e24228b975 were rechecked against the remote.
Documentation source check and strict MkDocs build pass; MkDocs retains an INFO
message about the existing migration-slices anchor. No required model worker
remains running. The next bounded same-state investigation above is still open.

## Terminal clock hypothesis,106c2ca95

The one read-only first-step probe preserves ALL1461 cold physical receipts and
finds identical h,theta,k,kmean,root uptake,frost factors and soil temperature.
However calendar-season t is363.00000000001455 cold and363.0 restored, while the
main t1900 clock agrees. The original sinusoidal lower boundary uses t directly.
The original TimeControl snaps the main clock at day end without recomputing t;
native initialization reconstructs t and loses its accepted floating point value.
Other observed differences (gwlm1,qbot,dimoca) are retained in the probe report;
this observation alone does not prove their irrelevance.

Selected repair attempt1: persist the actual accepted seasonal t in the existing
nonmacro auxiliary state, restore it after original initialization, retain all
original operation order and tolerances. Bump only the nonmacro codec versions
to S5NON005/S5HUP011 and reject missing/nonfinite seasonal state. Existing bound
old bundles/checkpoints remain usable with their original binary; no rebinding.
The new writer requires fresh own checkpoints, so the inexpensive11.9s SaltFarm
trajectory is selected to create them before testing all five own windows.
The existing active-macro codec/body is unchanged and is not executed.
