#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-top03-joint-microrelief-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
DELTA="${1:-0.2}"
HISTORY="${2:-rising}"
fail(){ echo "TOP03_JOINT_MICRORELIEF_FAIL $*" >&2; exit 91; }
python3 tests/fapp/make_top03_joint_nearsaturation.py "$BUILD/mod_b110_default_mvg_provider.f90" "$BUILD/unused.f90" "$DELTA" > "$BUILD/provider-generation.txt"
python3 - "$BUILD/mod_top03_microrelief_top_provider.f90" <<'PY'
from pathlib import Path
import re,sys
p=Path('tests/fapp/mod_top03_microrelief_top_provider.f90')
s=p.read_text()
def replace(name, body):
 global s
 pat=rf'  pure real\(real64\) function {name}\(self\) result\(value\).*?  end function {name}'
 s,n=re.subn(pat,body,s,count=1,flags=re.S)
 if n!=1:raise SystemExit(f'could not replace {name}')
replace('top03_wet_fraction', '''  pure real(real64) function top03_wet_fraction(self) result(value)
    class(top03_microrelief_provider_t), intent(in) :: self
    real(real64) :: x
    if (self%microrelief_amplitude_cm <= 0.0_real64) then
      value = 1.0_real64
    else
      x = min(1.0_real64,max(0.0_real64,self%external_stage_cm/self%microrelief_amplitude_cm))
      value = x**3*(10.0_real64+x*(-15.0_real64+6.0_real64*x))
    end if
  end function top03_wet_fraction''')
replace('top03_surface_storage', '''  pure real(real64) function top03_surface_storage(self) result(value)
    class(top03_microrelief_provider_t), intent(in) :: self
    real(real64) :: x, d
    d=self%microrelief_amplitude_cm
    if (d <= 0.0_real64) then
      value=self%external_stage_cm
    else if (self%external_stage_cm < d) then
      x=max(0.0_real64,self%external_stage_cm/d)
      value=d*(x**6-3.0_real64*x**5+2.5_real64*x**4)
    else
      value=self%external_stage_cm-0.5_real64*d
    end if
  end function top03_surface_storage''')
replace('top03_mean_wet_head', '''  pure real(real64) function top03_mean_wet_head(self) result(value)
    class(top03_microrelief_provider_t), intent(in) :: self
    real(real64) :: storage, fwet
    storage=self%surface_storage()
    fwet=self%wet_fraction()
    if (fwet <= 0.0_real64) then
      value=0.0_real64
    else
      value=storage/fwet
    end if
  end function top03_mean_wet_head''')
Path(sys.argv[1]).write_text(s)
print('SURFACE_HYPSOMETRY=smoothstep-CDF; storage=integral(fwet); mean_head=storage/fwet')
PY
python3 - "$BUILD/test.f90" "$HISTORY" <<'PY'
from pathlib import Path
import sys
src=Path('tests/fapp/test_sw_rib_top03_microrelief_stage_probe.f90').read_text()
src=src.replace('n_amp=5,n_stage=6,n_refine=4','n_amp=1,n_stage=6,n_refine=4')
src=src.replace('[0.0_real64,0.02_real64,0.05_real64,0.10_real64,0.25_real64]','[0.05_real64]')
if sys.argv[2]=='pulse':
 src=src.replace('n_amp=1,n_stage=6,n_refine=4','n_amp=1,n_stage=11,n_refine=4')
 src=src.replace('[0.005_real64,0.020_real64,0.050_real64,0.100_real64,0.200_real64,0.300_real64]',
  '[0.005_real64,0.020_real64,0.050_real64,0.100_real64,0.200_real64,0.300_real64, &\n       0.200_real64,0.100_real64,0.050_real64,0.020_real64,0.005_real64]')
src=src.replace('if(solve_result%top_flux>0.0_real64)then\n          result%solver_status=-903;result%stop_event=ie;result%stop_substep=is\n          return\n        end if','')
src=src.replace('if(solve_result%status/=SW_SOLVE_CONVERGED)then\n          result%stop_event=ie;result%stop_substep=is\n          return\n        end if',
'''if(solve_result%status/=SW_SOLVE_CONVERGED)then
          write(*,'(A,4(1X,I0),1X,A,1X,ES24.16)') 'FAIL_DIAG',ie,is,solve_result%status,solve_result%diagnostics%nonlinear_iterations,trim(solve_result%diagnostics%route),maxval(abs(workspace%richards%residual))
          result%stop_event=ie;result%stop_substep=is
          return
        end if''')
if sys.argv[2]!='rising' and sys.argv[2]!='pulse':
 raise SystemExit('history must be rising or pulse')
if not (('n_amp=1,n_stage=11,n_refine=4' if sys.argv[2]=='pulse' else 'n_amp=1,n_stage=6,n_refine=4') in src) or '[0.05_real64]' not in src:
 raise SystemExit('failed to narrow stage probe to D=0.05 cm')
Path(sys.argv[1]).write_text(src)
PY
python3 - "$BUILD/compile-order.txt" "$BUILD/mod_b110_default_mvg_provider.f90" "$BUILD/test.f90" "$BUILD/mod_top03_microrelief_top_provider.f90" <<'PY'
from pathlib import Path
import re,sys
order,provider,test=map(Path,sys.argv[1:4])
stub=Path('tests/fsi/fsi04_real_headcalc_stubs.f90')
top=Path('tests/fmr/mod_fmr04_fixed_top_provider.f90')
probe=Path('tests/fapp/mod_top03_microrelief_top_provider.f90')
smooth_probe=Path(sys.argv[4]) if len(sys.argv)>4 else None
headcalc=Path('src/legacy/b1_10_port/headcalc.f90')
candidates=[stub,top,probe,provider]+([smooth_probe] if smooth_probe else [])+sorted(p for p in Path('src').rglob('*.f90') if 'src/legacy/' not in p.as_posix())+[headcalc,test]
mr=re.compile(r'^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)',re.I)
ur=re.compile(r'^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)',re.I)
mods={};uses={}
for p in candidates:
 ls=p.read_text(errors='replace').splitlines();mods[p]=[m.group(1).lower() for l in ls if (m:=mr.match(l))];uses[p]=[u.group(1).lower() for l in ls if (u:=ur.match(l))]
providers={}
for p in [stub,top,probe,provider]+([smooth_probe] if smooth_probe else []):
 for m in mods[p]:providers[m]=p
for p in candidates:
 if p in (stub,top,probe,provider,smooth_probe,headcalc,test):continue
 for m in mods[p]:providers.setdefault(m,p)
required=set();unresolved=set()
def add(p):
 if p in required:return
 required.add(p)
 for m in uses.get(p,[]):
  q=providers.get(m)
  if q is not None and q!=p:add(q)
  elif q is None and (m.startswith('mod_') or m=='variables'):unresolved.add((p.as_posix(),m))
add(test);add(headcalc)
if unresolved:raise SystemExit(f'unresolved module dependencies: {sorted(unresolved)}')
deps={p:{providers[m] for m in uses.get(p,[]) if m in providers and providers[m] in required and providers[m]!=p} for p in required}
ordered=[];temp=set();done=set()
def visit(p):
 if p in done:return
 if p in temp:raise RuntimeError(f'cycle {p}')
 temp.add(p)
 for q in sorted(deps[p],key=lambda x:x.as_posix()):visit(q)
 temp.remove(p);done.add(p);ordered.append(p)
for p in sorted(required,key=lambda x:x.as_posix()):visit(p)
order.write_text('\n'.join(p.as_posix() for p in ordered)+'\n')
print(f'JOINT_MICRORELIEF_COMPILE_CLOSURE_FILES={len(ordered)}')
PY
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
 OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
 while IFS= read -r source; do
  key="$(printf '%s' "$source" | tr '/.' '__')"; obj="$OUT/$key.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj" || fail "compile O$opt $source"
  objects+=("$obj")
 done < "$BUILD/compile-order.txt"
 gfortran -O"$opt" "${objects[@]}" -o "$OUT/test" || fail "link O$opt"
 "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; fail "runtime O$opt"; }
 cat "$BUILD/provider-generation.txt"; cat "$OUT/output.txt"
 echo "TOP03_JOINT_MICRORELIEF_O${opt}=COMPLETED"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || { diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || true; fail 'O0/O2 numerical output mismatch'; }
echo 'TOP03_JOINT_MICRORELIEF_O0_O2_IDENTITY=PASS'

