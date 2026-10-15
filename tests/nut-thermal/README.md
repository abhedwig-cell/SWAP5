# Accepted thermal soil-N tests

Run `run_profile.py` with `N_THERMAL_PROFILE_DIR` set to a new output directory.
It builds one real production provider at O0/O2 and extracts the original B111
depth loop mechanically from the immutable source archive.

Run `run_composition.py` with `N_THERMAL_COMPOSITION_DIR` set to a new directory
and `N_THERMAL_LITERAL_PROFILE` pointing to that extracted literal include.
It retains the complete existing calendar process/day/BASE joint drivers and
adds a thermal joint driver. The thermal variant replaces prescribed-temperature
negatives with certified-state negatives; the original negatives still execute
in the unchanged BASE driver. Literal organic/mineral/supply, whole-N,
senescence, rollback, retry, replay, opaque and fresh-process continuation
assertions remain active. Thermal temperatures are obtained independently from
the literal loop over the actual accepted profile. Native files use separate
names, so BASE and thermal evidence cannot overwrite one another.

After a successful composition, run `check_restart.py` with
`N_THERMAL_RESTART_DIR`, and `check_trace_policy.py` with `N_THERMAL_POLICY_DIR`.
Both also require `N_THERMAL_COMPOSITION_DIR`. The latter reuses only the verified
objects in this live composition and compiles/links/executes a new seam driver;
it is not a cross-run cache. Five negative backend requests at each optimization
prove that absent opt-in and incompatible requests still reject without changing
the committed heat, water, history or certificate.

`resume_composition.py` records an explicit same-session recovery after a
driver-only error. It requires named previous raw evidence and a provider commit,
checks unchanged production bytes and artifact hashes, labels each reused event,
and executes the changed driver and all O2 commands. It never converts a failed
event into PASS. Its attempted development run is retained as failed evidence;
final composition is a fresh independent O0/O2 build after the backend seam change.

These are scoped scientific tests. They do not establish canonical admission or
claim that old broad source guards have accepted the shared backend postimage.
