# TOP03 bounded inundation interval contract

Implementation checkpoint, not production admission. Baseline: 757caabcbda7af41da414091a9ec7b2f69add63f. Canonical reconciliation: e2d18564383e1350b0b9a68af0eaf668dac784af.

This slice owns opt-in BASE external inundation, the accepted surface exchange carrier and participant component receipt. Existing FAPP09 drainage and default-off BASE contracts remain held fixed. It touches invariants 3, 7, 11, 13 and 28. No shared committed-state layout is changed.

Local SWAP ponding remains included in SWAP column storage. Ribasim owns the represented secondary surface-water storage. The external supply receipt includes the water required for local SWAP ponding; product geometry must ensure that local ponding is not also represented as the same stored volume in Ribasim. Overlapping volume ownership is not admitted by this contract.

External head is an imposed boundary condition, not a locally closed pond equation during Newton. The solver result has a default-false typed `external_surface_head_imposed` discriminator. Only the imposed-head adapter sets it. HeadCalc then retains soil conservation and head convergence but does not demand the unknown external supply from the atmosphere-only pond balance. No provider evaluation computes or publishes an external transfer.

The first runtime profile requires head > max(0,sill), head >= local start ponding, zero evaporation and snowmelt, nonnegative precipitation/irrigation/runon, and no competing fixed top flux. Accepted positive soil-to-surface qtop is explicitly rejected until exfiltration/runoff composition is qualified. Optional states remain restricted by existing BASE admission gates. Equality with start ponding keeps imposed head active in subsequent accepted half steps.

After convergence, soil_entry = -accepted qtop * dt. The pure materializer gives signed SWAP-to-external transfer T = atmosphere - evaporation - soil_entry - (S1-S0). The SWAP ledger replaces its soil-face top entry with atmosphere - evaporation - T. It does not add T to an already complete soil-face booking. Component receipt validation changes no physical ledger term.

Window exchange and residual are captured/restored in the transaction attempt context, exactly like drainage. Full-versus-half selection, rejected attempts and retries restore the appropriate carrier. Backend observation exposes the selected carrier only after a completed interval. Scalar publication and commit reject top-active candidates. Component commit compares independent subsurface and top terms against the same live candidate and captured origin.

For the bounded single-level participant, resolved_heads_cm(1) materializes both the drainage control and opt-in external top head in the existing cm datum. Default-off forcing remains unchanged. The product adapter must supply that datum; arbitrary datum transforms are not admitted here.

Required qualification: O0/O2 real BASE convergence, surface and total mass closure, accepted full/half carrier, wrong receipt rejection with live origin preserved, correct exactly-once commit, scalar bypass rejection, stale origin rejection, anti-masking, same-origin changed-head replay, bounded-profile rejection and external-off preservation. Live Ribasim application/geometry admission remains separate from this SWAP-side candidate.
