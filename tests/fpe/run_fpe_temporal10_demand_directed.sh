#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-temporal10-${GITHUB_RUN_ID:-local}-$$"
N="${TEMPORAL10_N:-10000}"
REPS="${TEMPORAL10_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

CAND="$BUILD/mod_reference_richards_temporal_indicator_candidate.f90"

python3 - "$CAND" <<'PY'
from pathlib import Path
import sys
s=Path("src/solver/mod_reference_richards_temporal_indicator.f90").read_text()

old="""       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED
"""
new="""       SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE, SW_TEMPORAL_INDICATOR_UNAVAILABLE, &
       SW_TEMPORAL_INDICATOR_FAILED, CONSTITUTIVE_DEMAND_WATER_CONTENT, &
       CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_CAPACITY
"""
if old not in s:
    raise SystemExit("TEMPORAL10 import anchor missing")
s=s.replace(old,new,1)

old="""    select type (constitutive => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       scale = max(1.0_real64, abs(constitutive%step_duration), abs(dt))
       if (abs(constitutive%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
       call constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, capacity_base, dkdh_base)
       call constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, conductivity_candidate, &
            capacity_candidate, dkdh_candidate)
    type is (b110_direct_retention_provider_t)
       scale = max(1.0_real64, abs(constitutive%analytical%step_duration), abs(dt))
       if (abs(constitutive%analytical%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
       call constitutive%evaluate(request%base_state%pressure_head, water_base, conductivity_base, capacity_base, dkdh_base)
       call constitutive%evaluate(solve_result%candidate_state%pressure_head, water_candidate, conductivity_candidate, &
            capacity_candidate, dkdh_candidate)
    class default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'constitutive-policy-deferred'
       return
    end select
"""
new="""    select type (constitutive => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       scale = max(1.0_real64, abs(constitutive%step_duration), abs(dt))
       if (abs(constitutive%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
       call constitutive%evaluate_demand(request%base_state%pressure_head, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
            water_base, conductivity_base, capacity_base, dkdh_base)
       call constitutive%evaluate_demand(solve_result%candidate_state%pressure_head, CONSTITUTIVE_DEMAND_WATER_CONTENT, &
            water_candidate, conductivity_candidate, capacity_candidate, dkdh_candidate)
       call constitutive%evaluate_demand(solve_result%candidate_state%pressure_head, CONSTITUTIVE_DEMAND_CAPACITY, &
            water_candidate, conductivity_candidate, capacity_candidate, dkdh_candidate)
    type is (b110_direct_retention_provider_t)
       scale = max(1.0_real64, abs(constitutive%analytical%step_duration), abs(dt))
       if (abs(constitutive%analytical%step_duration-dt) > 16.0_real64*epsilon(1.0_real64)*scale) then
          indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
          indicator_result%route = 'constitutive-dt-mismatch'
          return
       end if
       call constitutive%evaluate_demand(request%base_state%pressure_head, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
            water_base, conductivity_base, capacity_base, dkdh_base)
       call constitutive%evaluate_demand(solve_result%candidate_state%pressure_head, CONSTITUTIVE_DEMAND_WATER_CONTENT, &
            water_candidate, conductivity_candidate, capacity_candidate, dkdh_candidate)
       call constitutive%evaluate_demand(solve_result%candidate_state%pressure_head, CONSTITUTIVE_DEMAND_CAPACITY, &
            water_candidate, conductivity_candidate, capacity_candidate, dkdh_candidate)
    class default
       indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
       indicator_result%route = 'constitutive-policy-deferred'
       return
    end select
"""
if old not in s:
    raise SystemExit("TEMPORAL10 constitutive block anchor missing")
s=s.replace(old,new,1)
Path(sys.argv[1]).write_text(s)
PY

python3 - "$BUILD/candidate_runner.sh" "$CAND" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
cand=Path(sys.argv[2]).resolve()
root=Path(sys.argv[3]).resolve()

old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
if old_root not in runner: raise SystemExit("TEMPORAL10 root seam missing")
runner=runner.replace(old_root,f'ROOT="{root}"\ncd "$ROOT"',1)

runner=runner.replace(
'python3 - "$fixture" <<\'PY\'',
'python3 - "$fixture" "$TEMPORAL10_IND_SOURCE" <<\'PY\'',
1)
runner=runner.replace(
'fixture=Path(sys.argv[1]).resolve()\n',
'fixture=Path(sys.argv[1]).resolve()\nindicator=Path(sys.argv[2]).resolve()\n',
1)
old='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
'''
new='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/solver/mod_reference_richards_temporal_indicator.f90":
        print(indicator)
    else:
        print(p)
'''
if old not in runner: raise SystemExit("TEMPORAL10 module seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/candidate_runner.sh"

MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh | tee "$BUILD/base.txt"

TEMPORAL10_IND_SOURCE="$CAND" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash "$BUILD/candidate_runner.sh" | tee "$BUILD/cand.txt"

python3 - "$N" "$BUILD/base.txt" "$BUILD/cand.txt" <<'PY'
import re,sys
n=int(sys.argv[1])
def parse(p):
    txt=open(p).read()
    m=re.search(
      r'MULTI04_P1C_SUMMARY\|N=(\d+)\|W1_SECONDS=([^|]+)\|W2_SECONDS=([^|]+)\|W4_SECONDS=([^|]+)\|'
      r'SPEEDUP2=([^|]+)\|SPEEDUP4=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)',txt)
    if not m: raise SystemExit(f"missing summary {p}")
    return dict(n=int(m.group(1)),w1=float(m.group(2)),w2=float(m.group(3)),w4=float(m.group(4)),
                q=float(m.group(7)),t=float(m.group(8)))
b=parse(sys.argv[2]); c=parse(sys.argv[3])
if b["n"]!=n or c["n"]!=n: raise SystemExit("population mismatch")
if b["q"]!=c["q"] or b["t"]!=c["t"]:
    raise SystemExit("semantic checksum mismatch")
s1=b["w1"]/c["w1"]; s4=b["w4"]/c["w4"]
print(f"TEMPORAL10_SUMMARY|N={n}|BASE_W1={b['w1']:.12f}|CAND_W1={c['w1']:.12f}|W1_SPEEDUP={s1:.6f}|"
      f"BASE_W4={b['w4']:.12f}|CAND_W4={c['w4']:.12f}|W4_SPEEDUP={s4:.6f}|QSUM={b['q']:.17e}|TSUM={b['t']:.17e}")
if n==1000 and c["w4"]/b["w4"]>1.02:
    raise SystemExit(f"N=1000 regression gate failed {c['w4']/b['w4']}")
if n==10000 and s4<1.03:
    raise SystemExit(f"N=10000 advancement gate failed {s4}")
if n==40000 and s4<1.05:
    raise SystemExit(f"N=40000 advancement gate failed {s4}")
print("FPE_TEMPORAL10_DEMAND_DIRECTED=PASS")
PY
