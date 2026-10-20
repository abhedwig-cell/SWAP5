# SWAP5-PERF01 exact runtime optimization contract

Status: proposed implementation, not canonical admission. Baseline b0c2e94b.

The measured 50-node profile calls the stable MvG storage-increment path approximately once per residual evaluation. The two powers of the previous pressure head are invariant during a single explicit solve. The adapter may prepare exactly those expressions once and supply them to the original increment arithmetic. No algebraic substitution, temporal tolerance, residual criterion, or trial acceptance policy changes.

Preparation is call-local, only for the exact default-MvG provider type. Its original parameter pointer and step duration remain authoritative. Other providers retain their original dispatch. The temporary provider is never published, committed, checkpointed, or reused between solves, half steps, retries, columns or restarts. Each node compares its supplied previous head to the prepared origin; mismatches use the original path. A conservative bounded preparation domain avoids introducing eager overflowing powers for extreme inputs that the original routine might return from early. Outside it the original formula remains active.

Inactive explicit macropore physics no longer allocates or clears two arrays, including a per-residual clear. Every read of those arrays is under the existing active-provider/rate contract. Active providers retain their original zeroed arrays. Matrix-area configuration can be resolved once per call. Macropore source-freezing permission MUST remain residual-synchronous because candidate pond supply changes it; the initial exploratory hoist was removed before admission.

Affected invariants: 3 (trial isolation), 5 (worker scratch), 7 (conservative acceptance), 23 (physics versus numerical policy), 25 (Reference), 27 (optional physics cost). No shared public abstract interface or accepted-state layout changes.

Qualification: exact prepared/unprepared increment comparison including changed origins, saturation, near-saturation, branch crossings, entry-pressure smoothing and elastic storage at O0/O2; complete binary state/flux/mass/work trajectories for eight synthetic 50-node regimes at O0/O2/O3; focused real transactional/restart and active-macropore production gates. Byte identity is required for this implementation optimization. Existing 1e-12 independent per-step mass assertion stays fixed. No new relaxed tolerance.

These diagnostics use prescribed root/drain fluxes, not a live seasonal crop or a real HRU. Historical SWAP4 and actual HRU application comparisons must remain separately identified until executed. A default 0.005-day step bypasses outer adaptive transaction policy in the diagnostic solver matrix; it cannot prove full-model timestep equivalence.
