# PPA-WU05B10 generated linear drainage with bracketed low-air frost

Status: implemented candidate; actual runtime and preservation qualification pending. B9 is independently admitted via PR #1048 and its closeout PR #1049.

The separate OFF-by-default `frost_low_air_response_drainage_active` selector requires the B9 response/frost selector, admitted LINEAR response levels, B6 normal drainage and B8 physical low-air depths. Generated level count must match finite negative physical depths in both backend and ordinary application. Projection, other variants and root/salt/macropore/snow hybrids remain excluded. Existing guarded geometry and positive head/temperature numerical budgets retain their own contracts.

Generation uses the immutable trial-start hydraulic view before B8 selects final nodal drainage and final bottom flux. Final node sums drive the one existing solver sink and native/window receipts; bottom exchange stays with its existing owner. Raw generation diagnostics retain unmodified proposals. Full, half, rejected and fresh trials regenerate from their own input; no committed drainage or restart payload is added.

For the selected combination, full and half terminal hydraulic views independently generate their proposals before the existing branch, blocked-level and final-bottom-decision comparisons. Prescribed B8 retains its previous calls when the selector is absent. The source-depth implication matters: `bottom_depth < min(drain_depth)` blocks every level, so final total is already zero. Consequently the historical1e-6 total threshold cannot independently change bottom blocking in this finite-depth SWDIVD0 envelope. An earlier generic threshold-dependency interpretation is explicitly corrected in the source review; no unreachable transition is invented.

The completed process oracle covers216 actual LINEAR plus guarded corrected FrozenBounds compositions, both air regimes, four depth patterns including front equality, three activation values, three scales including tiny surviving totals, and three bottom signs. O0/O2 outputs and final nodal/bottom bit parity agree. This does not qualify the pending actual runtime.

The candidate actual runtime retains an owned consistent nonuniform grid, six depth/bottom groups,65536 direct steps each, head1e-6cm and temperature1e-4C horizon limits and hard mass1e-12cm. Local head3e-11cm, temperature1e-7C and solver head absolute/relative1e-12 are explicit numerical policy. Results remain pending until the complete source-bound gate finishes.

Authority: `integration/audits/PPA_WU05B10_SOURCE_REVIEW.json`, `integration/audits/PPA_WU05B10_PREREGISTRATION.json`, `integration/audits/PPA_WU05B10_STATUS.json`. Commands: `tests/frost/run_ppa_wu05b10_low_air_response_source.sh` and `tests/frost/run_ppa_wu05b10_low_air_response_runtime.sh`.

No SWDIVD1 redistribution, new node distribution, uniform/unbracketed front or last-node interpretation, non-LINEAR joint response, projected/fully implicit groundwater coupling, new phase-change physics, seasonal accuracy or full legacy equivalence is claimed. Aggregate frost migration remains incomplete.
