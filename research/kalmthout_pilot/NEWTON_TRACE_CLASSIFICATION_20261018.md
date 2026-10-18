# Kalmthout production Newton trace classification (2026-10-18)

Source: existing GitHub Actions run 39125001908, artifact 12135892353, dry_diagnostic.log. Parsed 1012 KALMTHOUT_NEWTON records. No new execution.

- 881 surface-flux iteration reports; all trace acceptance flags F; candidate top-node pressure heads from -36059.031963 to -869.47517443 cm.
- 131 ponded-head iteration reports; all trace acceptance flags T; candidate top-node pressure heads from 1.0000000000 to 1.0085277629 cm.
- The flags describe Newton candidate acceptance, NOT completion/commit of the requested weather hour. The failed hour has 547 solver rejections, zero mass or temporal rejections.
- This localizes rejected Newton candidates to the flux branch in this trace. It does not yet prove incorrect derivatives or scientific equivalence with legacy SWAP4.
- Focused research export workflow file and trigger are present on research/kalmthout-sw5-state-export-20261018, but a new state-export run has not been independently confirmed through the available connector (push-specific run enumeration unavailable). Do not say the new full state has been exported.
- Next scientific gate: exact accepted state and directional finite-difference Jacobian against production flux branch; compare transition rule with legacy. Keep canonical untouched.
