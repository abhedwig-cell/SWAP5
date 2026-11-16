# K: original soil-air/ceramic-plate lower boundary

WORKSTREAM SWAP5-NOMACRO-COVERAGE01; ownbranch codex/nomacro-coverage11.
BASELINE canonical3fb625da73031885624987d42ad922cb184c96e5; actual J receipt
BLOCK_J_MERGE.json verifies exact qualified tree and both frozen release refs.
Current Status-A named RC2 scope unchanged. This is an experimental successor,
not a production release, macro/MODFLOW or general Richards/performance task.

Read original readswap: SWBOTB allowed1..9;8 reads optional hplate[-1000,0],
default0. Mode9 has original DATE9A/HBOT9 and DATE9B/QBOT9 tables: do NOT infer
MODFLOW ownership merely from its number. Mode9 and strict solute1/5 are deferred
to their own receipt audit. First K covers actual mode8 only, including original
zero/open threshold and explicit negative ceramic-plate pressure, chemical/water,
and an external BBC-file route if first physical qualification permits.

HeadCalc residual uses its actual local flboth and hgrad to select zero flux or
-kmean(NN+1)*hgrad(NN+1). Original Fluxes reconstructs qbot AFTER HeadCalc from
stock balance. That reconstructed number cannot be a circular independent trial
receipt. Extend only selected8 generated receipt with an explicit finite candidate
boundary flux from the ORIGINAL HeadCalc trial. Do not overwrite original qbot,
change original boundary laws/thresholds/Newton iterations or lower guards.
Complete source/input identity binds this physical compatibility; default images
must remain exact. No new accepted boundary state: flboth is trial workspace,
reselected from accepted head by original routine; never serialize it as physics.

Before public activation: actual production receipt component O0/O2 using complete
native original module closure, explicit zero/open/no-flux/invalid contracts;
then generated real Windows short mode8 runs, fresh hosted full1096 water/chemical
HPLATE0/-50, native2/365/530 and natural active/closed outlet windows, hard water/
solute guards, rollback/origin isolation/external recovery, original standalone
reference diagnostics and fresh unchanged default source gate. Preserve every
failure or censor. Source-only original provider may be reused only after its
source/compiler SHA verification. No unrelated F-CI/platform/performance campaign.

Invariants2/3/4/7/13/21/23/29: explicit ephemeral flux, owned accepted state, no
implicit physical switch, exact immutable origin and unchanged independent budgets.
Whole science/energy/full original option coverage remain NOT_QUALIFIED.
