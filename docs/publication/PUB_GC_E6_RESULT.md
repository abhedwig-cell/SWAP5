# PUB-GC E6 result — hydrological stress extension

## Status

**CLOSED_NEGATIVE_WITH_BOUNDARIES**

E6 tested two preregistered routes toward a non-trivial finite-window feedback case without changing production physics or numerical tolerances.

### Route 1 — admitted active-drainage tangent

The F-GC31 active-drainage predictor completed and produced a mass-complete response, but the corresponding production prescribed-head corrector profile is not admitted. The mismatch is structural: the production head-forcing route requires `bottom_mode=5`, while the admitted smooth F-GC31 drainage projection requires `bottom_mode=2`. The reference corrector therefore returned `KERNEL_STATUS_NOT_ADMITTED` before any transaction attempt. Live MODFLOW execution was correctly skipped.

### Route 2 — accepted-state / predictor-flux screen

Twenty state/flux combinations were evaluated inside the existing prescribed-head-compatible fixture. Eight low-flux predictors completed; all twelve cases at `q_bot >= 1e-2 cm/day` exhausted the transaction retry sequence. None of the predictor-ready cases retained the preregistered symmetric `±1e-4 m` corrector domain, so the deterministic E6-B candidate count was zero.

## Scientific conclusion

E6 did not demonstrate a positive strong-feedback synthetic coupling case.

That negative outcome is informative. The current evidence shows that the route from “larger local SWAP response” to “stronger valid partitioned coupling” is constrained by component capability and response-domain admission before outer coupling convergence becomes the limiting mechanism.

The result strengthens rather than weakens the interpretation of E3:

- the existing E3 fixture remains a valid weak-feedback control;
- simply increasing flux or wetness does not create a scientifically admissible strong-feedback case;
- a qbot tangent for an active process does not imply availability of the corresponding prescribed-head corrector;
- failed component trials must not be relabelled as coupling instability.

E6 is therefore closed as a negative stress-extension study. No production architecture or tolerance is changed to manufacture a positive case.

## Programme consequence

The next PUB-GC evidence step is a realistic admitted application case, E7. It should test the coupling method in a hydrological profile that already owns the needed physical processes and boundary semantics, rather than continuing synthetic parameter escalation inside the restricted E3 fixture.
