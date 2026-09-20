# F-ROM-LARE BC2-C6D frozen-state BEMR mechanism closeout

## Decision

**BEMR is supported for prescribed-flux boundary qualification.**

C6D is exposed mechanism evidence, not blind validation and not a free-running Layer-ROM test. The Reference trajectory is unchanged and the BEMR candidate never feeds back into it.

## Qualification

All 2,304 prescribed-head moving observations across R01-R04 are strictly state/moment realizable and numerically qualified. The directly projected first moment and storage are reconstructed with the frozen C6C bounded entropy-dual P3 map.

On the pooled primary 150, 155 and 157.5 cm interfaces:

- RMSE decreases from 0.0087091 to 0.0060752 cm/day;
- mean absolute interface/history signed bias decreases from 0.0011379 to 0.0001901 cm/day;
- sign mismatches decrease from 229 to 190;
- moving RMSE improves separately at all three primary interfaces.

These are exactly the prospectively frozen C6D support gates.

## Preserved nonuniformity and tail risk

BEMR is not uniformly better.

The maximum absolute primary error increases from 0.10266 to 0.18420 cm/day. The BEMR maximum occurs for R02, observation 225, at 157.5 cm: the first observation immediately after the preregistered RISE-to-FALL phase reversal. The fine Reference flux is -0.05287 cm/day, while BEMR predicts +0.13133 cm/day.

At 155 cm, pooled sign mismatches also increase from 35 for CURRENT_LAYER_FACE to 39 for BEMR.

Neither quantity was a C6D adjudication gate, so the prospectively defined positive decision stands. They are preserved as exposed mechanism risks and may not be tuned away.

## Interpretation

C5R showed that adding D8-to-D12 storage breadth at shared 2.5-cm bottom support does not repair the response under CURRENT_LAYER_FACE. C6D now shows that adding a conservation-derived first water-content moment and using a realizability-preserving profile map materially improves the frozen-state interface-flux mechanism on the preregistered primary vector.

That supports missing subgrid shape information as a real part of the propagation deficiency. It does not yet establish free-running hydrological fidelity, stability through boundary-mode changes, or application adequacy.

## Next authority

C6E must qualify the lower prescribed-flux boundary algebraically and response-free. The dynamic state, moment definition, BEMR dual order and constitutive interval remain frozen.

Only after C6E passes may a fresh blind free-running BEMR experiment be preregistered. That future blind experiment must include an explicit fast-transition/tail guard in addition to pooled metrics, because C6D exposed a large reversal-transition error.
