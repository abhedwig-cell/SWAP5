# STRIP01 independent component refinement preregistration

Research only. Pinned baseline 5d3ef86670f66379bf03c777e46c49dc698ae663;
canonical 53059a5225fa45cd6121d4bc4c7310dcc4e0660c unchanged at reconciliation.

Use the existing reference-floor sampler to examine nonlinear solutions without
claiming temporal acceptance. A temporary, independent committed state carries
only these diagnostic samples. It never modifies the fifty coupling origins.
No production source, solver stopping threshold or admission guard changes.
The sampler's absence of temporal certification is intentional for measurement,
not permission to publish coupled windows without an error gate.

Panel: requested interval 3e-6, 1e-4, 1e-3 d; equal subdivisions N=1,2,4,16;
initial head -5 m; fixed interface head -5, -5.000001, -5.05 m; inward
rain 1 mm/d; physical SWAP Ss=1e-5 /m. Additional zero-elasticity same-head
controls at 3e-6 and 1e-4 d. All existing mass and nonlinear tolerances remain.

Read out pressure head, water content, storage change and integrated bottom
exchange. Compare each complete trajectory to N=16 at identical final time.
Head discrepancy is compared to the unchanged 1e-5 cm budget; this is an
observed refinement discrepancy, not a rigorous bound or universal admission.
Convergence requires successful finer solves; otherwise classify unresolved.
Retain nonlinear failures, partial progress and immutable-origin checks.

The comparison determines whether the current certificate is conservative in
this bounded startup panel and whether changed-bottom-head failure persists
without the temporal indicator. A new numerical route would need separate
preregistration, refinement evidence and publication/restart qualification.

## Additional unit-correct configuration repair, before execution

Read-only HeadCalc instrumentation on the 1e-6 m changed-head case found a
zero final Newton correction, but rate residual 4.2469e-12 cm/d exceeded its
effective 2.8e-12 cm/d gate. HeadCalc residual includes dz*delta(theta)/dt;
its convergence tolerance is a rate, whereas the original research specification
stated the budget as 1e-12 cm of water depth. These are different quantities.

Preserve the original fixed-rate panel as negative evidence. Test an opt-in
research configuration mapping the unchanged 1e-12 cm depth budget to total
rate tolerance 1e-12/dt cm/d and local rate tolerance 1e-12/(30*dt) cm/d.
No head or temporal budget changes. The separate transaction/global mass guard
remains 1e-12 cm; it is not replaced by the rate test. The existing native
roundoff floor still applies. This is a declared dimensional configuration
repair, not a production solver patch or tolerance fitting exercise.

Repeat the same independent refinement panel and compare complete profiles,
exchange and mass. A pass alone is insufficient; retain actual refinement
errors and verify origin identity. Only then retry the existing short/extended
coupled panel with this numerical configuration. Coupled volume threshold,
publication order and all temporal limits remain frozen.

## Additional explicit Newton error-allocation experiment

The dimensional repair completed 33/44 trajectories versus 18/44 originally,
but finer changed-head paths still failed. Print-only observation found rate
residual below the corrected gate while normalized Newton head change was
7.0692e-12, exceeding the fixed 1e-12 iteration threshold. This distinguishes
iteration stopping from the unchanged 1e-5 cm trajectory error budget.

Before execution, allocate at most 1e-8 cm (0.001 of that trajectory budget)
to the Newton head stopping test. Absolute criterion 1e-8 cm and relative
criterion 1e-8/500=2e-11, bounded by profile head magnitude <=500 cm.
Leaving that magnitude domain invalidates this allocation. Keep the same
integrated mass guard and same temporal certificate budget. This is a distinct
research numerical-configuration variant; it does not qualify the original
strict panel. Do not accept a variant solely from successful solves: repeat
all refinement measurements, keep actual trajectory errors above budget as
negative evidence, and test unchanged mass/replay before coupled use.

## Datum-invariance conditioning diagnostic

The repaired extended coupled case passes three windows then reaches the outer
ceiling with interface mismatch ~1e-18 m3/d but native MF convergence false.
At near-zero exchange the absolute MF rate criterion is stricter than roundoff
in a linear system expressed around absolute head -5 m. Test a uniform +5 m
translation of MF top, base, DRN stage, initial head and API head coordinates.
Convert MF head back to the physical land datum before SWAP materialization.
Ss, thickness, T, head gradients, drain head excess, exchange, physical storage
and all numerical tolerances remain unchanged. API RHS is formed directly in
the translated coordinate to avoid cancellation of large absolute-head terms.

This is an exact coordinate transformation of the confined MF equations, not
a changed boundary condition. Compare original and shifted short physical
head/exchange/balance. Preserve the original failure and do not infer success
for long forcing until actual coupled windows and budget tests complete.
