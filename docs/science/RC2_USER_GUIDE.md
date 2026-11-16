# SWAP5 no-macro RC2: user guide

Candidate: SWAP5-NOMACRO-RC2-20261116. The source ZIP's RELEASE_MANIFEST.json
states its exact Git commit and every packaged file hash. The fixed branch is
`release/swap5-nomacro-rc2-20261116`; it is created only after qualification.
This is a fixed release candidate, not an official release tag or public release.

## Scope and limits

| Project/model | Full days | Saved day |
| --- | ---: | ---: |
| Grassgrowth / HYBRID_GRASSGROWTH_WATER | 1827 | 365 |
| Hupsel / HYBRID_HUPSEL_WATER | 1096 | 365 |
| SaltFarm04dS / HYBRID_SALTFARM_WATER | 1461 | 109 |

Only these named original/prepared SWMACRO0 profiles have the user-release
claim. Additional original-process choices in the current code retain their
separate bounded evidence. Harmonic, hourly-weather, pulsed-rain and alternative
constitutive refusals/censors are not silently promoted to full support.
Active macropores remain outside scope and are never silently switched off.
Grass/Hupsel use daily-actual-v1; SaltFarm uses physical-growth-v2. Experimental
projects retain the original adaptive/default policies. No failure-driven
fallback, new tolerance or physical equation is introduced for this RC.

Functional completion and scientific equivalence are separate. Original oxygen
criteria and underqualified Hupsel584 references remain limited/failed. Own
restart includes native original heat state; no full independently closed
physical-energy budget or invented flux is claimed. The public route shares
its declared CSV/output preparation with any original431 comparison; a literal
original S_CONC request may fail and that original failure remains visible.

## Install and unpack

Use Python3.12+ and x86-64 GNU gfortran, gcc and ar on PATH. Python runtime uses
the standard library. On Windows, an MSYS2 UCRT64 GNU installation is suitable;
on Ubuntu install python3, gfortran, gcc and binutils through the system package
manager. Check `python --version`, `gfortran --version`, `gcc --version`, `ar --version`
(or `python3` on Ubuntu). Required compiler versions/identities are recorded in
the qualification proof; own checkpoints remain compiler/build bound.

Unpack the source ZIP into a new directory and run commands there. Git and a
research provider are not required. Before unpacking, verify the archive SHA256
against the accompanying receipt with PowerShell `Get-FileHash ARCHIVE.zip -Algorithm SHA256`
or Ubuntu `sha256sum ARCHIVE.zip`. RELEASE_MANIFEST.json supplies the source
commit and file hashes; the official proof receipt supplies the archive hash.
Do not edit input or manifest files to reuse a stale checkpoint.

## Prepare, build, run and restart

These are single-line commands, usable on Windows and Ubuntu. Use `python3`
instead of `python` where required. All output directories must be new.
Source preparation compiles immutable bundled original sources but executes no
model or active-macropore case. It needs no downloaded research data.

```text
python -B tools/solute/run_water.py --no-macro-release --prepare-sources --reference-work provider
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work provider --build-only --kernel-opt O2 --output salt-build
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work provider --build-bundle salt-build --days 1461 --checkpoint-at 109 --timeout-seconds 60 --output salt-full
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work provider --build-bundle salt-build --days 1461 --restart salt-full/accepted-column-1-day-109.zip --restart-day 109 --timeout-seconds 60 --output salt-restarted
```

For Grass/Hupsel substitute their model, day count and saved day from the table,
and use distinct build/full/restarted directories. The source provider is shared
within the same validated compiler/profile; model instances and their states are
independent. Build bundles, source, inputs and checkpoints must match exactly.
After source updates rebuild; never rebind an old checkpoint by editing metadata.
A foreign build/platform/native checkpoint is refused rather than assumed portable.

The full output has RESULT.json, daily.jsonl, the original result_output.csv
under original/, and the requested accepted-column checkpoint. Each day must
be committed. Water/kernel and active-solute accounting retain the1e-10 guards.
Rejected candidates are not published as accepted states.

## Reproduce RC qualification

```text
python -B tools/solute/qualify_compiler_profile.py --output qualification
```

In the source ZIP, this validates every manifest file before source preparation.
It executes the literal public commands: fresh O0 short/O2 full periods, control
runs, own long restart suffixes, native/auxiliary and printed-CSV equality,
unchanged guards, refusal and external independent-instance checks. Preparation,
compile/link, model/controller and validation times are kept separate in logs.
Each native user invocation has a60second cap; installation/compiler setup is
separate. A successful result is COMMON_PROFILE_PUBLIC_O0_O2_FULL_OWN_PASS.
No scientific acceptance criterion is weakened by this functional test.

The qualification, archive checksum and freeze receipt are published under
`integration/f-ci/nomacro-rc2-20261116/` on canonical and referenced by the RC PR.
The code ZIP deliberately excludes historical proof archives and the Git database;
full documentation/evidence history remains in abhedwig-cell/SWAP5. The earlier
RC1 branch and evidence are preserved unchanged. No automatic research campaign
or timer is part of this delivered candidate.
