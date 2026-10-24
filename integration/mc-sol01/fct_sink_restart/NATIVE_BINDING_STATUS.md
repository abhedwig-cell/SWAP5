# Native production binding: demonstrated domain gaps

Based on canonical2de14588. This record supersedes any suggestion that dispatch
activation alone completes native FCT support. The actual native caller is
`app/solute_project/main.f90`, which invokes `run_pond_joint_interval` and
constructs cell distances/weights from its native grid. Its supported production
domain includes unequal layers and nonzero surface storage.

The actual production reactive interface accepts both diagnostic cases. The
admitted research sink FCT rejects each with status1 and leaves input chemical
storage unchanged. O0/O2 each execute three cases: uniform/no-pond control
returns production0/FCT0; one doubled layer returns production0/FCT1; uniform
with0.1cm ending surface storage returns production0/FCT1. Eleven real sources
are compiled with bounds and floating-point checks. Raw commands, return codes,
streams and timing are in NATIVE_DOMAIN_RESULT.json; source-bound probe is
check_native_domain.py. This is a small real-interface probe, not execution or
qualification of the full native project.

Production activation is unfinished. Neither removing the guards nor silently
replacing a rejected correction by low-order transport establishes native FCT
accuracy. Next implementation: generalize reconstruction/limiting to unequal
cell geometry and compose the corrected interior solve with the existing pond
mass owner, then qualify actual native positive-input/evaporation/runoff traces
and bind numerical selection to restart identity. Existing PR1415/1418 research
and disk qualification remain valid in their admitted bounded domains.
