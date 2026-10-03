# SCV full/half temporal context contract

Status: proposed, opt-in research; not production admission.
Baseline: b52ad0d866a04098394ba1d90ecbfae36d4f4b57.
Remote sibling at reconciliation: f5063889e4a7ab1ad075509e1ce9f4c1955ee58d.
The sibling works on generated hydraulic providers. It lacks this local SCV slice.
This work changes neither HeadCalc nor hydraulic constitutive providers.

Add an optional context-aware temporal callback to the transaction model. Its
fallback delegates to the existing endpoint callback. Capture the full context
before restoring the common checkpoint; compare it with the composed-half
context. Acceptance still selects composed halves and restores only their context.
Rejection still restores the common checkpoint. No new persistent state field,
restart layout, or external publication operation is introduced.

For SCV alone, the finite indicator is the maximum of: sum over nodes of
abs(theta_full-theta_half)*dz (cm water, no spatial cancellation); max absolute
pressure-head difference (cm head); absolute local surface storage difference
(cm water); and absolute signed external exchange integral difference (cm water).
The existing scalar temporal tolerance bounds every channel in its native cm
unit. This is a conservative research budget, not a calibrated production policy.
Missing/malformed/nonfinite state or context fails closed. Unsupported physical
owners remain excluded by SCV admission. Mass tolerances are unchanged.

Positive external exchange means SWAP to external owner. With soil-face flux
qtop positive upwards, Qsoil=-qtop, and external supply Qexternal positive into
SCV: dS=dt*(Qexternal-Qsoil), dWsoil=dt*(Qsoil+qbot),
d(Wsoil+S)=-Eexternal+dt*qbot. Soil-face transfer is internal to the combined
owner and is replaced, not added, in its external mass ledger. Surface storage
is the solver ponding_depth candidate (a water depth, not surface head).

Accepted candidate metadata may be inspected after numerical acceptance;
committed column and external publication require the outer commit/receipt
boundary. Failed outer windows must expose no carrier even after internal progress.

The existing surface-water participant rejected every window with more than one
accepted transaction. SCV alone now permits a completely accepted composed
window using the selected top and subsurface exchange integrals. Legacy/default
single-transaction admission is retained. Component receipts still require both
components separately, matching origin, interval, and exactly-once commit.

This isolated branch carries the local SCV postimage, not the concurrent
hydraulic-research sibling. Reconciliation found no sibling production source
changes since common checkpoint 4166548d; its documentation/test-generator delta
is deliberately not overwritten on the shared branch. Canonical admission and
integration with that sibling remain separate tasks.
