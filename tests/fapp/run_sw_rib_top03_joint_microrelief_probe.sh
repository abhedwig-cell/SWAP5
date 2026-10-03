#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-top03-joint-microrelief-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
DELTA="${1:-0.2}"
HISTORY="${2:-rising}"
HEAD_TOL="${3:-1e-12}"
SURFACE="${4:-smooth}"
LEVELS="${5:-standard}"
BOTTOM_K_DERIVATIVE="${6:-off}"
fail(){ echo "TOP03_JOINT_MICRORELIEF_FAIL $*" >&2; exit 91; }
python3 tests/fapp/make_top03_joint_nearsaturation.py "$BUILD/mod_b110_default_mvg_provider.f90" "$BUILD/unused.f90" "$DELTA" > "$BUILD/provider-generation.txt"
python3 - "$BUILD/mod_top03_microrelief_top_provider.f90" "$SURFACE" <<'PY'
from pathlib import Path
import re,sys
p=Path('tests/fapp/mod_top03_microrelief_top_provider.f90')
s=p.read_text()
if sys.argv[2]=='legacy':
 Path(sys.argv[1]).write_text(s)
 print('SURFACE_HYPSOMETRY=legacy-piecewise')
 raise SystemExit(0)
if sys.argv[2]!='smooth':raise SystemExit('surface law must be smooth or legacy')
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
python3 - "$BUILD/headcalc.f90" "$BOTTOM_K_DERIVATIVE" <<'PY'
from pathlib import Path
import sys
p=Path('src/legacy/b1_10_port/headcalc.f90')
s=p.read_text()
needle='!  Convergence could not been reached\n'
diag='''! Test-only failure trace; this runs before HeadCalc rolls the failed trial back.
   if (.NOT.flnonconv) continue
   write(*,'(A,2(1X,I0),9(1X,ES24.16))') 'HEADFAIL', state%numbit, &
        maxloc(abs(state%h(1:NN)-fsi_ws%old_head(1:NN)),dim=1), CritDevBalCp, CritDevBalTot, &
        CritDevh2Cp, CritDevh1Cp, maxval(abs(fsi_ws%residual(1:NN))), &
        maxval(abs(state%h(1:NN)-fsi_ws%old_head(1:NN))), &
        state%h(maxloc(abs(state%h(1:NN)-fsi_ws%old_head(1:NN)),dim=1)), &
        fsi_ws%old_head(maxloc(abs(state%h(1:NN)-fsi_ws%old_head(1:NN)),dim=1)), &
        fsi_ws%residual(maxloc(abs(state%h(1:NN)-fsi_ws%old_head(1:NN)),dim=1))
   write(*,'(A,8(1X,ES24.16))') 'HEADFAIL_SURFACE', state%hsurf, provider_dynamic_top_result%surface_head, &
        provider_dynamic_top_result%actual_top_flux, state%qtop, state%pond, state%pondm1, dt, sum1
   write(*,'(A,8(1X,ES24.16))') 'HEADFAIL_BOTTOM', state%qbot, fsi_ws%provider_k(NN), state%k(NN), &
        state%kmean(NN+1), state%dimoca(NN), fsi_ws%provider_dkdh(NN), matrix_fraction(NN), fsi_ws%dfdh_main(NN)
   do i=1,NN
      write(*,'(A,1X,I0,11(1X,ES24.16))') 'HEADFAIL_NODE', i, state%h(i), fsi_ws%old_head(i), &
           state%theta(i), state%dimoca(i), state%k(i), fsi_ws%residual(i), &
           fsi_ws%dfdh_upper(i), fsi_ws%dfdh_main(i), fsi_ws%dfdh_lower(i), &
           fsi_ws%delta_head(i), fsi_ws%head_gradient(i)
   end do
'''
if s.count(needle)!=1:raise SystemExit('HeadCalc failure insertion point not unique')
if sys.argv[2] not in ('off','on','analytic'):
 raise SystemExit('bottom K derivative mode must be off, on (finite difference), or analytic')
s=s.replace(needle,diag+needle)
if sys.argv[2] in ('on','analytic'):
 decl='   real(8)                          :: QMpLatSsSav\n'
 more='''   real(8)                          :: QMpLatSsSav
   real(8)                          :: top03_fd_eps, top03_kplus, top03_kminus, top03_hsave, top03_dkbotdh
   logical                          :: top03_kplus_ok, top03_kminus_ok
'''
 if s.count(decl)!=1:raise SystemExit('could not add test-only derivative locals')
 s=s.replace(decl,more)
 if sys.argv[2]=='analytic':
  imp='CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY'
  exp=imp+', CONSTITUTIVE_DEMAND_DKDH'
  if s.count(imp)!=1:raise SystemExit('could not import test-only derivative demand')
  s=s.replace(imp,exp)
 jac='      call jacobian_F()\n'
 fd_add='''      call jacobian_F()
      ! Research-only counterfactual: add dK/dh for free-drainage qbot=-K(h).
      if (provider_constitutive_active .and. swkimpl == 0 .and. swbotb == 7) then
         top03_dkbotdh = 0.0d0
         top03_hsave = state%h(NN)
         top03_fd_eps = max(1.0d-7,abs(top03_hsave)*1.0d-7)
         state%h(NN) = top03_hsave + top03_fd_eps
         call evaluation_context%constitutive%evaluate_demand(state%h(1:numnod), CONSTITUTIVE_DEMAND_WATER_CONTENT, &
              fsi_ws%provider_theta, fsi_ws%provider_k, fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
         call evaluation_context%constitutive%evaluate_point_conductivity(NN,state%h(NN),fsi_ws%provider_theta(NN), &
              top03_kplus,top03_kplus_ok)
         state%h(NN) = top03_hsave - top03_fd_eps
         call evaluation_context%constitutive%evaluate_demand(state%h(1:numnod), CONSTITUTIVE_DEMAND_WATER_CONTENT, &
              fsi_ws%provider_theta, fsi_ws%provider_k, fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
         call evaluation_context%constitutive%evaluate_point_conductivity(NN,state%h(NN),fsi_ws%provider_theta(NN), &
              top03_kminus,top03_kminus_ok)
         state%h(NN) = top03_hsave
         if (top03_kplus_ok .and. top03_kminus_ok) then
            top03_dkbotdh = (top03_kplus-top03_kminus)/(2.0d0*top03_fd_eps)
            fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + top03_dkbotdh
         end if
      end if
'''
 analytic_add='''      call jacobian_F()
      ! Research-only analytic dK/dh from the generated regularized provider.
      if (provider_constitutive_active .and. swkimpl == 0 .and. swbotb == 7) then
         call evaluation_context%constitutive%evaluate_demand(state%h(1:numnod), &
              CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_DKDH, fsi_ws%provider_theta, &
              fsi_ws%provider_k, fsi_ws%provider_capacity, fsi_ws%provider_dkdh)
         top03_dkbotdh = fsi_ws%provider_dkdh(NN)
         fsi_ws%dfdh_main(NN) = fsi_ws%dfdh_main(NN) + top03_dkbotdh
      end if
'''
 add=fd_add if sys.argv[2]=='on' else analytic_add
 if s.count(jac)!=1:raise SystemExit('could not add test-only bottom derivative')
 s=s.replace(jac,add)
 s=s.replace("   write(*,'(A,8(1X,ES24.16))') 'HEADFAIL_BOTTOM', state%qbot, fsi_ws%provider_k(NN), state%k(NN), &\n        state%kmean(NN+1), state%dimoca(NN), fsi_ws%provider_dkdh(NN), matrix_fraction(NN), fsi_ws%dfdh_main(NN)",
 "   write(*,'(A,9(1X,ES24.16))') 'HEADFAIL_BOTTOM', state%qbot, fsi_ws%provider_k(NN), state%k(NN), &\n        state%kmean(NN+1), state%dimoca(NN), fsi_ws%provider_dkdh(NN), matrix_fraction(NN), fsi_ws%dfdh_main(NN), &\n        top03_dkbotdh")
Path(sys.argv[1]).write_text(s)
PY
python3 - "$BUILD/test.f90" "$HISTORY" "$HEAD_TOL" "$LEVELS" "$BOTTOM_K_DERIVATIVE" <<'PY'
from pathlib import Path
import sys
src=Path('tests/fapp/test_sw_rib_top03_microrelief_stage_probe.f90').read_text()
imp='soil_water_solve_result_t, SW_SOLVE_CONVERGED'
imp_exp=imp+', &\n       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY, CONSTITUTIVE_DEMAND_DKDH'
if sys.argv[5]=='analytic':
 if src.count(imp)!=1:raise SystemExit('could not add derivative-oracle demand imports')
 src=src.replace(imp,imp_exp)
 initcall='    call hyd%evaluate(h0,theta0,conductivity,capacity,dkdh)\n'
 if src.count(initcall)!=1:raise SystemExit('could not insert derivative-oracle call')
 src=src.replace(initcall,initcall+'    call top03_check_analytic_dkdh()\n')
 anchor='  end subroutine initialize_fixture\n\n  subroutine run_trajectory'
 oracle='''  end subroutine initialize_fixture

  subroutine top03_check_analytic_dkdh()
    real(real64) :: hprobe, eps, analytic, finite_difference, kplus, kminus
    real(real64) :: heads(numnod), theta(numnod), conductivity_check(numnod), capacity_check(numnod), dkdh_check(numnod)
    integer :: j
    do j=1,5
      select case(j)
      case(1); hprobe=-0.300_real64
      case(2); hprobe=-0.150_real64
      case(3); hprobe=-0.050_real64
      case(4); hprobe=-0.005_real64
      case(5); hprobe=-0.0001_real64
      end select
      eps=max(1.0e-6_real64,abs(hprobe)*1.0e-3_real64)
      heads=hprobe
      call hyd%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_DKDH, &
           theta,conductivity_check,capacity_check,dkdh_check)
      analytic=dkdh_check(1)
      heads=hprobe+eps
      call hyd%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
           theta,conductivity_check,capacity_check,dkdh_check)
      kplus=conductivity_check(1)
      heads=hprobe-eps
      call hyd%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT+CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
           theta,conductivity_check,capacity_check,dkdh_check)
      kminus=conductivity_check(1)
      finite_difference=(kplus-kminus)/(2.0_real64*eps)
      write(*,'(A,I0,3(1X,ES24.16))') 'JOINT_DKDH_ORACLE_DIAG',j,analytic,finite_difference, &
           analytic-finite_difference
      if(abs(analytic-finite_difference)>1.0e-6_real64+2.0e-5_real64*abs(finite_difference)) &
           error stop 'analytic regularized dK/dh differs from central difference'
    end do
    write(*,'(A)') 'JOINT_DKDH_ORACLE=PASS'
  end subroutine top03_check_analytic_dkdh

  subroutine run_trajectory'''
 if src.count(anchor)!=1:raise SystemExit('could not add derivative oracle procedure')
 src=src.replace(anchor,oracle)
src=src.replace('n_amp=5,n_stage=6,n_refine=4','n_amp=1,n_stage=6,n_refine=4')
src=src.replace('[0.0_real64,0.02_real64,0.05_real64,0.10_real64,0.25_real64]','[0.05_real64]')
tol=sys.argv[3]
src=src.replace('request%numerical%head_abs_tolerance=1.0e-12_real64',f'request%numerical%head_abs_tolerance={tol}_real64')
src=src.replace('request%numerical%head_rel_tolerance=1.0e-12_real64',f'request%numerical%head_rel_tolerance={tol}_real64')
if sys.argv[2]=='pulse':
 src=src.replace('n_amp=1,n_stage=6,n_refine=4','n_amp=1,n_stage=11,n_refine=4')
 src=src.replace('[0.005_real64,0.020_real64,0.050_real64,0.100_real64,0.200_real64,0.300_real64]',
  '[0.005_real64,0.020_real64,0.050_real64,0.100_real64,0.200_real64,0.300_real64, &\n       0.200_real64,0.100_real64,0.050_real64,0.020_real64,0.005_real64]')
src=src.replace('if(solve_result%top_flux>0.0_real64)then\n          result%solver_status=-903;result%stop_event=ie;result%stop_substep=is\n          return\n        end if','')
src=src.replace('if(solve_result%status/=SW_SOLVE_CONVERGED)then\n          result%stop_event=ie;result%stop_substep=is\n          return\n        end if',
'''if(solve_result%status/=SW_SOLVE_CONVERGED)then
          write(*,'(A,5(1X,I0),1X,A,2(1X,ES24.16))') 'FAIL_DIAG',ie,is,solve_result%status,solve_result%diagnostics%nonlinear_iterations, &
               maxloc(abs(workspace%richards%residual),dim=1),trim(solve_result%diagnostics%route), &
               maxval(abs(workspace%richards%residual)),maxval(abs(solve_result%candidate_state%pressure_head-workspace%richards%old_head))
          result%stop_event=ie;result%stop_substep=is
          return
        end if''')
if sys.argv[2]!='rising' and sys.argv[2]!='pulse':
 raise SystemExit('history must be rising or pulse')
if sys.argv[4]=='extended':
 src=src.replace('n_refine=4','n_refine=6')
 src=src.replace('refinements(n_refine)=[1,2,4,8]','refinements(n_refine)=[1,2,4,8,16,32]')
elif sys.argv[4]!='standard':
 raise SystemExit('levels must be standard or extended')
if not (('n_amp=1,n_stage=11,n_refine=' if sys.argv[2]=='pulse' else 'n_amp=1,n_stage=6,n_refine=') in src) or '[0.05_real64]' not in src:
 raise SystemExit('failed to narrow stage probe to D=0.05 cm')
Path(sys.argv[1]).write_text(src)
PY
python3 - "$BUILD/compile-order.txt" "$BUILD/mod_b110_default_mvg_provider.f90" "$BUILD/test.f90" "$BUILD/mod_top03_microrelief_top_provider.f90" "$BUILD/headcalc.f90" <<'PY'
from pathlib import Path
import re,sys
order,provider,test=map(Path,sys.argv[1:4])
stub=Path('tests/fsi/fsi04_real_headcalc_stubs.f90')
top=Path('tests/fmr/mod_fmr04_fixed_top_provider.f90')
probe=Path('tests/fapp/mod_top03_microrelief_top_provider.f90')
smooth_probe=Path(sys.argv[4]) if len(sys.argv)>4 else None
headcalc=Path(sys.argv[5]) if len(sys.argv)>5 else Path('src/legacy/b1_10_port/headcalc.f90')
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
