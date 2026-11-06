# Private pond thermal native logical qualification

This work qualifies a private native-reader integrity candidate against canonical
`9a55a1780de67db95a6003ab397f332ed2c0e965`. It does not deploy that candidate or
change scientific admission. The existing
[thermal pond contract](MC_SOL01_THERMAL_POND_CONTRACT.md) remains authoritative.

The complete candidate lives in
`tests/dataqual15_hupsel/pond_thermal_native_candidate.f90`. Production
`src/adapter/mod_pond_thermal_restart_file.f90` is unchanged. The candidate reads
the two host-logical header fields as raw bytes, validates the actual host TRUE
and FALSE representations, and only then interprets them. It also validates both
serialized Rutter parameter logicals before restoration. Proper writer output
is preserved; malformed-writer qualification is still outstanding. LDWET is a
real number, and micro-present is an integer with its existing domain check;
neither is incorrectly treated as a logical.

The proof executes the complete original Reference/heat/reactive-pond and
Black/Rutter drivers, including their original physical assertions, literal and
quad oracles, eight base refinement meshes, rollback, CRC and identity controls,
and fresh-process restart. Each baseline and candidate build compiles its entire
provider DAG and the real publication C object at O0 and O2. The only runner
projection adds an explicit 64 MiB Windows PE stack on both sides; it changes no
assertion, physical recipe, solver, tolerance, schema or publication contract.
Windows evidence contains 2,288 actual compiler objects, 54 byte-identical proper
generation files and 48 independently resealed malformed-logical public-reader
controls. All 48 candidate controls reject atomically. The baseline fails 28
reject assertions; its uncensored diagnostics remain in the capsule.

The first local controller processes exited unsuccessfully at their final source
guard because the raw-versus-Git-blob hash-policy record changed while they were
running. Those process failures are retained explicitly. They are not relabelled
successful. Separate current guard and capsule remeasurement bind the completed
native results to exact source content, with CRLF transport normalization only.
Raw compiler input hashes, all source bytes, objects, commands, Windows link
responses, executables, native files and diagnostics are retained losslessly.

Authority and recovery:
`integration/dataqual15_hupsel/POND_THERMAL_NATIVE_RECOVERY_20261106.json`.
`pond_thermal_native_evidence.py` independently remeasures the complete capsule
and refuses source, missing-object, CRC, diagnostic and positive-file mutations.
The POSIX baseline/candidate full O0/O2 proof is separately required. This private
scope covers actual S5PT0001 and S5PT0004 compositions; it does not qualify
standalone S5PT0002/0003, mature Hupsel equivalence or arbitrary corrupt writers.
All four layouts, corrupt-writer controls and affected production preservation
must be qualified before a later production deployment. Solver/retry/tolerance,
mass, restart ownership and fail-closed boundaries remain unchanged.
