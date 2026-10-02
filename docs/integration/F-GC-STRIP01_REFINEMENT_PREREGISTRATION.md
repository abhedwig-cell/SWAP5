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
