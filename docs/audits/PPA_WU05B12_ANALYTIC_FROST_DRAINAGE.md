# PPA-WU05B12 analytic frost drainage composition

## Status and authority

Implemented and persisted; runtime qualification is in progress. Baseline is
B11 canonical closeout `879a9c65b0badb650c9b4e4fe194b7e6ffcc02f6`.
The versioned source review, preregistration and current status are under
`integration/audits/PPA_WU05B12_*.json`. This is a bounded composition of
already admitted DRAMET2 Hooghoudt IPOS1/2/3 and Ernst IPOS4/5 with normal
and guarded low-air frost. Aggregate frost migration remains incomplete.

The independent F-VQ38 authority is exact branch head
`49728b999b884a37643908c1dad40269f4e2db9b`. Its 148 scientific cases and
132 tangent checks pass on the actual changed process modules at O0/O2.
Old owner commit locators are no longer navigable, so the runner verifies
its exact certified immutable blobs against the admitted B11 baseline.
The unchanged independent oracle and probe remain the numerical authority.
Existing evaluator, preparation and validation bodies are unchanged;
only additive pure validator accessors and PURE annotations were added.
Literal drainage cutoff `diffl < 1e-10` is distinct from root `vsmall`.

## Interface and ownership

`frost_analytic_response_drainage_active` defaults to false. It requires the
B9 base selector and at least one analytic level. Existing LINEAR and
TABULATED mixtures are supported; TABULATED still requires the B11 selector.
Low-air requires the B10 selector and finite negative physical drain depths
with matching cardinality. Each analytic generator's physical drain bottom
must equal its frost drain depth exactly. Selected active parameters and
prepared data are validated; unrelated inactive LINEAR/TABULATED members
remain unused.

Generation still reads immutable trial-start GWL and writes one disposable
bottom-lumped proposal. The existing frost modifier produces final nodal
rates, which drive the existing single Richards sink and accepted receipts.
The B10 terminal full/half norm regenerates its own input proposals. No new
persistent state, restart layout, Jacobian or projection is introduced.

## Qualification boundary

The component gate passes 4,320 combinations across all five methods,
GWL activation/cutoff positions, four drain-depth patterns including front
equality, both air branches, signed second TABLE rates and three qbot signs.
Actual selected binding agrees with independent analytic equations; final
nodes, qbot and reporting match corrected B7 FrozenBounds bit for bit at
O0/O2.

Normal full runtime covers warm, partial and frozen trajectories for all
five methods and both bottom-flux signs, including actual signed TABLE
second levels. Its O0/O2 outputs are identical. Retry, mass at `1e-12 cm`,
accepted receipts, replay, application and empty-registry restart pass.
Further 16,384/32,768 reference trajectories for IPOS1/2/5 pass within the
unchanged `1e-6 cm` head and `1e-4 C` thermal comparison envelopes.
Low-air full runtime and further references are pending in the status record.
Its declared debug budgets remain B10's and establish no practical speed claim.

The first generated main had a concatenated END DO; repeated restart tests
then reused a nonempty test registry. Both fixture defects were corrected,
with negative evidence retained and full runners restarted. An additional
preflight test incorrectly assumed a negative Ernst fixed resistance was
outside the admitted parameter domain; it now tests an actual excluded zero
conductivity. Scientific validation and production domains were preserved.

Empirical interflow, EXTENDED_SIGNED, SWDIVD1 spatial distribution, fixed-weir,
GWL projection, directional/implicit drainage and root/salt/macropore/snow
hybrids remain outside this composition. No ice partition or latent-heat
claim is made.
