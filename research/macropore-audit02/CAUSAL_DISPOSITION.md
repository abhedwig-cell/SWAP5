# KNOWN CAUSE

Baseline canonical: 8dcda0fb247ae7823d720817d6340114d5227728.
Classification: B, inconsistent nonlinear state/acceptance contract, implemented
as deliberate macro-rate freezing after flunsatok(3). No production repair made.

The original HeadCalc activates three performance flags at dt<0.01. After the
third flag, vector_F(2) skips MACROPORE(2); jacobian_F also skips MACROPORE(3)
and its derivative subtraction. Matrix pressure/theta keep changing. Acceptance
checks F computed with the old QExcMpMtx, without a final coupled reevaluation.
Thus it solves the matrix equation with a frozen exchange, not the complete
coupled operator at the accepted pressure. The original selected source contains
both conditions: this mechanism is not introduced by the SWAP5 adapter.

The first step after exact native432 already shows this: t1900=36227, dt=.002,
iteration5/backtrack1, cached Fmax=4.375600473312605e-11 versus fresh
1.953059707936189e-5. No internally rejected attempt is needed for this witness.
This is first in the selected window, not a claim about the preceding432days.

The final438 live state repeats PR1655 exactly: cached5.801720215359296e-12,
fresh4.319762946264734,38 failing nodes. Pressure has moved89.87199698682484cm
at worst since the last rate evaluation. Three fork-only counterfactuals:

1. Change only flunsatok(3) to FALSE and call vector_F(2): F and Q equal fresh
   vector_F(1) exactly. This localizes the stale residual to the freeze condition.
2. Restore h to its last macro-evaluation value, reconstruct theta, call original
   MACROPORE(2): Q equals cached Q exactly. The cache belongs to that older h.
3. Call original MACROPORE(2) at accepted h: Q equals fresh Q exactly; F stays
   cached until reevaluated, directly separating exchange and residual caches.

The residual difference is explained by exchange to8.881784197001252e-16.
This is NOT full attribution of the79.51136565856024cm trajectory discrepancy,
a repaired trajectory, or proof that retained historical output is physically valid.

Rollback: original MacroStateVar saves/restores only ICpBtDm, VlMpDmCp,
WaUnMpDmCp. Four complete57,084,037-byte static snapshots inventory globals and
local SAVEs.39 symbols differ after the first real day15 rollback, including
SorpDmCp and ThtSrpRefDmCp. Matrix h/theta/GWL/pond, named macro stores,
wet-wall/event/cumulative absorption history are exact. Restoring240 macro and
MACRORATE/SATFLOW/ABSORPTION SAVE fields to pristine accepted origin, preserving
intentional numerical retry controls and evaluating at identical retry h/dt,
returns exactly the same Q and F as ordinary rollback. This falsifies those
omissions as the cause at this selected retry, not all rollback regimes.

All successful observers reproduce parent physical records and both complete
raw native endpoints exactly. Initial recompilation observers failed that guard
and remain rejected evidence. Original Ubuntu15.2 effective x86-64-v3/FMA target
had to be recovered; version string alone did not capture effective target.

Daily mass can close because the same stale exchange is subtracted from the
matrix equation and integrated with opposite sign in macro storage. Internal
exchange cancels in the integrated system budget. Conservation does not establish
constitutive/fixed-point consistency. Original MACROSTATE uses QExcMtxDmCp in
storage integration; it does not solve the coupled pressure again.

No new solver architecture, tolerance change, production patch, full481 run or
release promotion. Original no-macro release and GMD work remain independent.
A consistent contract must require residual and Jacobian to represent the named
trial state and an actual fresh coupled acceptance check before publication.
Do not implement another polishing loop or replay rejected PR1656 variants.

Publication: TRACE is directly relevant (state/source/evidence authority);
NUM-UNC may use scoped numerical-policy sensitivity evidence. A standalone
methods paper is not justified yet. First qualify a consistent contract on one
live step, then decide whether a minimal repair can be defended. Keep historical
behaviour, numerical consistency, physical defensibility and qualification separate.

Machine result: results/CAUSAL_RESULT.json. Raw new evidence is research-only.
Existing481,day438,directional evidence is linked under ../hybrid-water01/.
