# F-PE-MIQUAL03 closeout — fixed-flux forcing diversity

Date: 2026-10-01

Final status:

`QUALIFIED_MIQUAL03_FIXED_FLUX_FORCING_DIVERSITY`

Qualification authority:

- workflow run `36820978966`;
- job `110236273112`;
- workflow conclusion SUCCESS.

## Closure

MIQUAL03 closes positively.

The reference-first 25-case forcing bank produced 21 reference-valid cases across every frozen forcing class. All 21 adaptive cases pass physical, ownership, route and performance gates.

Aggregate:

- 21/21 adaptive physical passes;
- 100% reduced-route use;
- zero fallback/bypass;
- geometric-mean wall ratio 0.93717;
- geometric-mean deterministic work ratio 0.77659.

Four cases remain outside the qualified manager domain because the full reference failed under the frozen evidence profile.

## Direct successor

Open:

`F-PE-MIQUAL04 — dynamic-top runoff/ponding qualification`.

The successor should test the manager under atmospheric/dynamic-top switching and ponding/runoff where a saturated-tail moving-interface geometry is valid.

Reference preflight remains mandatory.

Do not reopen fixed-flux reconstruction micro-analysis without new evidence.

## Production boundary

Moving-interface manager remains explicit opt-in.

`LEGACY_NUMERICS` remains production default.
