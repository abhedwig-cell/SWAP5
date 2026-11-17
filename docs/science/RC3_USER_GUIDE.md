# SWAP5 no-macro RC3: user guide

Candidate: **SWAP5-NOMACRO-RC3-20261117**. The bundled
RELEASE_MANIFEST.json names the fixed source commit and every packaged file SHA256.
The accompanying PACKAGE.json and SHA256SUMS.txt bind the ZIP itself. This is a
source release candidate, not an official version tag or public GitHub release.
It supersedes RC2 for the selected user route; RC1/RC2 remain immutable.

## Named projects and limitations

| Project | Model | Full days | Save/restart day |
| --- | --- | ---: | ---: |
| Grassgrowth | HYBRID_GRASSGROWTH_WATER |1827 |365 |
| Hupsel | HYBRID_HUPSEL_WATER |1096 |365 |
| SaltFarm04dS | HYBRID_SALTFARM_WATER |1461 |109 |

The three named prepared SWMACRO0 profiles share one generic controller and
private original Fortran workers. No input switch is silently disabled. Active
macropores, including original Andelst, remain outside this release claim.
Grassgrowth/Hupsel retain configured-dtmax-daily-v1; SaltFarm retains
configured-dtmax-physical-growth-v2. These defaults are unchanged.

RC3 contains the admitted original water-balance/state repairs and additional
bounded experimental options since RC2, including local irrigation/rain stepping
and deterministic dry-uptake lookup state. The new
original-adaptive-local-wetting-v1 policy is **explicit and experimental**; the
registered commands below do not activate it. To select it for a separately
validated experimental input, use the existing --experimental-project and
--experimental-time-step-policy arguments. Frost, snow and active macropores are
outside that policy's domain. Its input, build and restart policies must match.
Bundled original correction recipes do not grant every option combination a
release or scientific qualification.

Functional completion and scientific equivalence remain separate. Original
oxygen criteria and the underqualified Hupsel584 reference remain failed or
limited. The experimental wetting case's original full nominal GWL comparison
remains FAIL (maximum2.678132cm Windows/2.782673cm Ubuntu); its independent
363–365 numerical time-grid/history attribution is bounded, not a general
groundwater error bound or whole scientific equivalence. Supported numerical
heat accounting is separately qualified; whole physical energy remains
incomplete and no missing energy flux is invented. No tolerance is relaxed.

## Install and verify

Use Python3.12+ and x86-64 GNU gfortran, gcc and ar on PATH. Windows can use
MSYS2 UCRT64; Ubuntu can use its system packages. The Python runtime uses only
the standard library. Check the four tools before building:

```text
python --version
gfortran --version
gcc --version
ar --version
```

Use python3 where appropriate on Ubuntu. On the qualified laptop, PowerShell can
add the existing compiler for this session:

```powershell
$env:PATH = 'C:\msys64\ucrt64\bin;' + $env:PATH
Get-FileHash .\SWAP5-NOMACRO-RC3-20261117.zip -Algorithm SHA256
Expand-Archive .\SWAP5-NOMACRO-RC3-20261117.zip -DestinationPath C:\SWAP5-RC3
Set-Location C:\SWAP5-RC3
```

Compare the hash with PACKAGE.json/SHA256SUMS.txt. Use a new extraction directory;
do not unpack over an old build. No Git checkout, research worktree or external
input download is required. Original source archives and selected inputs are
bundled. Source preparation compiles original sources and executes no model.

## Prepare once, build, run and restart

All output paths must be new. The provider can be shared within the same
validated compiler/profile. First prepare it:

```text
python -B tools/solute/run_water.py --no-macro-release --prepare-sources --reference-work provider
```

For SaltFarm:

```text
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work provider --build-only --kernel-opt O2 --output salt-build
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work provider --build-bundle salt-build --days 1461 --checkpoint-at 109 --timeout-seconds 60 --output salt-full
python -B tools/solute/run_water.py --no-macro-release --model HYBRID_SALTFARM_WATER --reference-work provider --build-bundle salt-build --days 1461 --restart salt-full/accepted-column-1-day-109.zip --restart-day 109 --checkpoint-at 1461 --timeout-seconds 60 --output salt-restarted
```

For Grassgrowth substitute HYBRID_GRASSGROWTH_WATER,1827days and365; for Hupsel
substitute HYBRID_HUPSEL_WATER,1096days and365. Use separate build/full/restarted
directories. These are continuations to the final total day, not another full
period after the saved day. Each accepted day has a committed receipt in
daily.jsonl, with independent water/kernel and active-solute guards of1e-10.
The original CSV is under original/result_output.csv; RESULT.json records
execution and timing. Rejected trials are not accepted physical state.

Rebuild after any source/compiler/policy/input change. **RC2 checkpoints are not
rebound to RC3**, nor are native checkpoints assumed portable across operating
systems. Foreign identity is refused. Keep accepted originals and their build
metadata together.

## Verify the complete user route

```text
python -B tools/solute/qualify_compiler_profile.py --output qualification
```

This validates all manifest files and runs the actual public commands: fresh
provider, all three O0 four-day/own2→4 controls, O2 full periods and exact long
own continuations, printed CSV and terminal native/auxiliary equality, unchanged
balances,12 refusal tests and6 external rollback/independent-instance controls.
O0/O2 names the SWAP5 kernel; original provider/donor remains O2. Each native
invocation retains its60second cap; source preparation and build/link costs are
separate. Successful final status is
COMMON_PROFILE_PUBLIC_O0_O2_FULL_OWN_PASS. Complete output artifacts and fixed
source/ZIP identity are supplied in the accompanying qualification receipt.
