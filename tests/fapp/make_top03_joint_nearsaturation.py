#!/usr/bin/env python3
"""Make a scratch-only joint theta/capacity/K transition provider and driver."""
import hashlib
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
provider_out, test_out = map(Path, sys.argv[1:3])
source_path = root / "src/solver/mod_b110_default_mvg_provider.f90"
# The research fixture transforms the unmodified provider. Keep its generator
# independent of any opt-in production experiment currently in the worktree.
BASELINE_PROVIDER_REF = "045db0527e94b6ef560698f02524a32bbc989622"
source = subprocess.check_output(
    ["git", "show", f"{BASELINE_PROVIDER_REF}:{source_path.relative_to(root).as_posix()}"], cwd=root, text=True
)
delta_h_cm = float(sys.argv[3]) if len(sys.argv) > 3 else 0.02
mode = sys.argv[4] if len(sys.argv) > 4 else "research"
if delta_h_cm <= 0.0:
    raise SystemExit("transition width must be positive")
delta = f"{delta_h_cm:.16e}_real64"

def replace_one(pattern, replacement, text, label):
    out, n = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if n != 1:
        raise SystemExit(f"expected one {label} replacement, found {n}")
    return out

# Replace the entire retention function. The research transition is C1 at both
# ends and uses the unmodified MvG retention law at its lower endpoint.
water = f'''  pure real(real64) function b110_watcon(c, head) result(watcon)
    real(real64), intent(in) :: c(:), head
    real(real64) :: help, h105, alfa, s, w, theta_mvg
    alfa = c(4)
    if (c(9) > B110_H_CRIT .and. head >= -{delta} .and. head < 0.0_real64) then
       s = (head + {delta})/{delta}
       w = s**3*(10.0_real64 + s*(-15.0_real64 + 6.0_real64*s))
       help = (1.0_real64 + abs(alfa*head)**c(6))**c(7)
       theta_mvg = c(1) + c(25)/help
       watcon = min((1.0_real64-w)*theta_mvg + w*c(2), c(2))
       return
    end if
    if (head >= 0.0_real64) then
       watcon = c(2)
    else
       if (c(9) > B110_H_CRIT) then
          if (head > B110_H_CRIT) then
             watcon = c(26) + c(27)*(head-B110_H_CRIT)
             watcon = min(watcon,c(2))
          else
             help = abs(alfa*head)**c(6)
             help = (1.0_real64 + help)**c(7)
             watcon = c(1) + c(25)/help
          end if
       else
          h105 = 1.05_real64*c(9)
          if (head >= h105) then
             watcon = c(2) + c(42)*head/(1.0_real64+c(41)*head)
          else
             help = abs(alfa*head)**c(6)
             help = (1.0_real64 + help)**c(7)
             watcon = c(1) + c(25)/(help*c(28))
          end if
       end if
    end if
  end function b110_watcon'''
source = replace_one(r"  pure real\(real64\) function b110_watcon\(c, head\).*?  end function b110_watcon", water, source, "water-content function")

# In the transition band return the exact derivative of the modified theta(h),
# so the solver's storage Jacobian and mass residual use the same curve.
capacity = f'''  pure real(real64) function b110_moiscap(c, head, step_duration) result(capacity)
    real(real64), intent(in) :: c(:), head, step_duration
    real(real64) :: alphah, h105, term1, term2, s, w, dw, theta_mvg, dtheta_mvg
    if (c(9) > B110_H_CRIT .and. head >= -{delta} .and. head < 0.0_real64) then
       s = (head + {delta})/{delta}
       w = s**3*(10.0_real64 + s*(-15.0_real64 + 6.0_real64*s))
       dw = 30.0_real64*s**2*(1.0_real64-s)**2/{delta}
       alphah = abs(c(4)*head)
       theta_mvg = c(1) + c(25)/(1.0_real64+alphah**c(6))**c(7)
       dtheta_mvg = c(25)*c(6)*c(7)*c(4)**c(6)*abs(head)**(c(6)-1.0_real64) / &
            (1.0_real64+alphah**c(6))**(c(7)+1.0_real64)
       capacity = (1.0_real64-w)*dtheta_mvg + dw*(c(2)-theta_mvg)
       return
    end if
    if (head >= 0.0_real64) then
       capacity = step_duration*1.0e-7_real64
    else
       alphah = abs(c(4)*head)
       if (c(9) > B110_H_CRIT) then
          if (head > B110_H_CRIT) then
             capacity = c(27)
          else
             term1 = alphah**c(30)
             term2 = c(25)/((1.0_real64 + term1*alphah)**c(31))
             capacity = c(29)*term2*term1
          end if
       else
          h105 = 1.05_real64*c(9)
          if (head >= h105) then
             capacity = c(42)/((1.0_real64+c(41)*head)**2)
          else
             term1 = alphah**c(30)
             term2 = (1.0_real64 + term1*alphah)**c(31)
             term2 = c(25)/term2
             capacity = c(29)*term2*term1/c(28)
          end if
       end if
       if (head > -1.0_real64 .and. capacity < step_duration*1.0e-7_real64) &
            capacity = step_duration*1.0e-7_real64
    end if
  end function b110_moiscap'''
source = replace_one(r"  pure real\(real64\) function b110_moiscap\(c, head, step_duration\).*?  end function b110_moiscap", capacity, source, "moisture-capacity function")

# Use the same smoothstep and the regularized saturation in a Mualem K law;
# blend continuously to Ks at h=0. This removes the near-saturated snap inside
# the one declared transition band only.
needle = "    relsat = (theta-c(1))/c(25)\n    ksatexm_applied = .false."
insert = f'''    relsat = (theta-c(1))/c(25)
    if (c(9) > B110_H_CRIT .and. head >= -{delta} .and. head < 0.0_real64) then
       s = (head + {delta})/{delta}
       w = s**3*(10.0_real64 + s*(-15.0_real64 + 6.0_real64*s))
       se = max(0.0_real64,min(1.0_real64,relsat))
       term1 = (1.0_real64-se**c(32))**c(7)
       term2 = c(3)*se**c(5)*(1.0_real64-term1)**2
       hconduc = min(c(3),(1.0_real64-w)*term2+w*c(3))
       return
    end if
    ksatexm_applied = .false.'''
if source.count(needle) != 1:
    raise SystemExit("expected one conductivity insertion point")
source = source.replace(needle, insert)
source = replace_one(
    r"  pure real\(real64\) function b110_hconduc\(c, head, theta, enable_ksatexm_extension\) result\(hconduc\)",
    "  pure real(real64) function b110_hconduc(c, head, theta, enable_ksatexm_extension) result(hconduc)\n    real(real64) :: s, w",
    source,
    "conductivity declarations",
)
source = replace_one(
    r"    real\(real64\) :: theta_local\n    logical :: need_theta, need_k, need_capacity, need_dkdh",
    "    real(real64) :: theta_local\n"
    "    real(real64) :: s, w, dw, se, se_power, term, term_slope, k_mvg, dk_mvg_dse, cap_local\n"
    "    logical :: need_theta, need_k, need_capacity, need_dkdh",
    source,
    "research conductivity derivative locals",
)
analytic_dk = f'''    if (need_dkdh) then
       dconductivity_dhead = 0.0_real64
       do i = 1, n
          if (self%parameters%cofgen(9,i) <= B110_H_CRIT .or. pressure_head(i) >= 0.0_real64) cycle
          w = 0.0_real64
          dw = 0.0_real64
          if (pressure_head(i) >= -{delta}) then
             s = (pressure_head(i)+{delta})/{delta}
             w = s**3*(10.0_real64+s*(-15.0_real64+6.0_real64*s))
             dw = 30.0_real64*s**2*(1.0_real64-s)**2/{delta}
          end if
          se = max(0.0_real64,min(1.0_real64,(water_content(i)-self%parameters%cofgen(1,i))/ &
               self%parameters%cofgen(25,i)))
          if (se <= 0.0_real64 .or. se >= 1.0_real64) then
             dconductivity_dhead(i) = 0.0_real64
             cycle
          end if
          se_power = se**self%parameters%cofgen(32,i)
          term = (1.0_real64-se_power)**self%parameters%cofgen(7,i)
          k_mvg = self%parameters%cofgen(3,i)*se**self%parameters%cofgen(5,i)*(1.0_real64-term)**2
          term_slope = self%parameters%cofgen(7,i)*self%parameters%cofgen(32,i)* &
               se**(self%parameters%cofgen(32,i)-1.0_real64)* &
               (1.0_real64-se_power)**(self%parameters%cofgen(7,i)-1.0_real64)
          dk_mvg_dse = self%parameters%cofgen(3,i)*(self%parameters%cofgen(5,i)* &
               se**(self%parameters%cofgen(5,i)-1.0_real64)*(1.0_real64-term)**2 + &
               2.0_real64*se**self%parameters%cofgen(5,i)*(1.0_real64-term)*term_slope)
          cap_local = b110_moiscap(self%parameters%cofgen(:,i),pressure_head(i),self%step_duration)
          dconductivity_dhead(i) = (1.0_real64-w)*dk_mvg_dse*cap_local/self%parameters%cofgen(25,i) + &
               dw*(self%parameters%cofgen(3,i)-k_mvg)
       end do
    end if'''
source = replace_one(
    r"    if \(need_dkdh\) dconductivity_dhead = 0\.0_real64",
    analytic_dk,
    source,
    "analytic regularized dK/dh",
)
provider_out.write_text(source)

test = (root / "tests/fapp/test_sw_rib_top03_surface_transition.f90").read_text()
for old, new in (("do bottom_case=1,3", "do bottom_case=1,1"),
                 ("do profile=1,3", "do profile=1,1"),
                 ("do history=1,3", "do history=3,3")):
    if test.count(old) != 1:
        raise SystemExit(f"expected one driver restriction: {old}")
    test = test.replace(old, new)
needle = " call initialize_b110_default_mvg_parameters(hp,cofgen)"
oracle = ''' call initialize_b110_default_mvg_parameters(hp,cofgen)
 call bind_b110_default_mvg_provider(hyd,hp,0.25_real64)
 max_dk_abs_error=0.0_real64; max_dk_relative_error=0.0_real64
 max_dk_fine_abs_error=0.0_real64; max_dk_fine_relative_error=0.0_real64
 do i=1,5
  select case(i)
  case(1); hstart=-1.25_real64
  case(2); hstart=-0.15_real64
  case(3); hstart=-0.015_real64
  case(4); hstart=-0.005_real64
  case(5); hstart=-0.0001_real64
  end select
  call hyd%evaluate(hstart,theta0,cond,cap,dkdh)
  base_theta=theta0(1); base_capacity=cap(1); base_dk=dkdh(1); hprobe=hstart(1)
  hstart=hprobe+1e-7_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); theta_hi=theta0(1); k_hi=cond(1)
  hstart=hprobe-1e-7_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); theta_lo=theta0(1); k_lo=cond(1)
  if(abs(base_capacity-(theta_hi-theta_lo)/2e-7_real64)>1e-7_real64) &
    error stop 'joint-transition capacity is inconsistent with theta derivative'
  hstart=hprobe+1e-5_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); k_hi=cond(1)
  hstart=hprobe-1e-5_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); k_lo=cond(1)
  fd_dk=(k_hi-k_lo)/2e-5_real64
  max_dk_abs_error=max(max_dk_abs_error,abs(base_dk-fd_dk))
  max_dk_relative_error=max(max_dk_relative_error,abs(base_dk-fd_dk)/max(abs(fd_dk),1e-30_real64))
  if(abs(base_dk-fd_dk)>1e-6_real64+2e-5_real64*abs(fd_dk)) then
    print '(a,4(es24.16,a))','DKDH_ORACLE_FAIL h=',hprobe,', analytic=',base_dk,', finite_difference=',fd_dk,', error=',abs(base_dk-fd_dk)
    error stop 'joint-transition analytic dK/dh failed finite-difference oracle'
  end if
  hstart=hprobe+5e-7_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); k_hi=cond(1)
  hstart=hprobe-5e-7_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); k_lo=cond(1)
  fd_dk=(k_hi-k_lo)/1e-6_real64
  max_dk_fine_abs_error=max(max_dk_fine_abs_error,abs(base_dk-fd_dk))
  max_dk_fine_relative_error=max(max_dk_fine_relative_error,abs(base_dk-fd_dk)/max(abs(fd_dk),1e-30_real64))
  if(abs(base_dk-fd_dk)>1e-6_real64+2e-5_real64*abs(fd_dk)) then
    print '(a,4(es24.16,a))','DKDH_FINE_ORACLE_FAIL h=',hprobe,', analytic=',base_dk,', finite_difference=',fd_dk,', error=',abs(base_dk-fd_dk)
    error stop 'joint-transition analytic dK/dh failed fine finite-difference oracle'
  end if
 end do
 print '(a,2(es24.16,a))','DKDH_ORACLE_MAX',max_dk_abs_error,', relative=',max_dk_relative_error
 print '(a,2(es24.16,a))','DKDH_FINE_ORACLE_MAX',max_dk_fine_abs_error,', relative=',max_dk_fine_relative_error
 hstart=0.0_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh)
 if(cap(1)/=0.0_real64)error stop 'joint-transition saturated capacity must follow constant theta'
 hstart=-1e-7_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); theta_lo=theta0(1)
 hstart=1e-7_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); theta_hi=theta0(1)
 if(abs((theta_hi-theta_lo)/2e-7_real64)>1e-7_real64) &
    error stop 'joint-transition theta derivative is discontinuous at exact saturation'
 hcut=-((1.0_real64-1e-6_real64)**(-1.0_real64/hp%cofgen(7,1))-1.0_real64)** &
     (1.0_real64/hp%cofgen(6,1))/hp%cofgen(4,1)
 hstart=hcut-1e-8_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); kleft=cond(1)
 hstart=hcut+1e-8_real64; call hyd%evaluate(hstart,theta0,cond,cap,dkdh); kright=cond(1)
 if(abs(kright-kleft)>1e-5_real64)error stop 'joint-transition retained K discontinuity'
 print '(a,4(a,es24.16))','JOINT_ORACLE',',',hcut,',',kleft,',',kright,',',kright-kleft'''
if test.count(needle) != 1:
    raise SystemExit("expected one constitutive initialization in test driver")
if mode == "production":
    oracle = oracle.replace(
        " call bind_b110_default_mvg_provider(hyd,hp,0.25_real64)\n",
        " call bind_b110_default_mvg_provider(hyd,hp,0.25_real64)\n"
        " hstart=-0.01_real64\n"
        " call evaluate_b110_default_mvg_state_direction(hyd,hstart,hstart,direction_theta,direction_k, &\n"
        "      direction_available,direction_route)\n"
        " if(direction_available .or. trim(direction_route)/='near-saturation-transition-direction-unqualified') &\n"
        "      error stop 'state directional service must fail closed for transition law'\n"
        " call evaluate_b110_default_mvg_water_content_direction(hyd,hstart,hstart,direction_theta, &\n"
        "      direction_available,direction_route)\n"
        " if(direction_available .or. trim(direction_route)/='near-saturation-transition-direction-unqualified') &\n"
        "      error stop 'water-content directional service must fail closed for transition law'\n"
    )
if mode != "baseline":
    test = test.replace(needle, oracle)
    test = test.replace("real(real64)::heads(3),hstart(numnod),theta0(numnod),dt,transfer_cm",
                        "real(real64)::heads(3),hstart(numnod),theta0(numnod),hprobe,base_theta,base_capacity,base_dk,fd_dk,k_hi,k_lo,max_dk_abs_error,max_dk_relative_error,max_dk_fine_abs_error,max_dk_fine_relative_error,theta_hi,theta_lo,hcut,kleft,kright,dt,transfer_cm")
    if mode == "production":
        test = test.replace(" implicit none", " use mod_b110_default_mvg_directional_provider, only: &\n  evaluate_b110_default_mvg_state_direction, evaluate_b110_default_mvg_water_content_direction\n implicit none", 1)
        test = test.replace("real(real64)::heads(3),hstart(numnod),theta0(numnod),hprobe,",
                            "real(real64)::direction_theta(numnod),direction_k(numnod),heads(3),hstart(numnod),theta0(numnod),hprobe,")
        test = test.replace("logical::continued", "logical::continued,direction_available", 1)
        test = test.replace("character(len=8)::geometry_arg", "character(len=96)::direction_route\n character(len=8)::geometry_arg", 1)
test_out.write_text(test)
print(f"JOINT_TRANSITION_DELTA_H_CM={delta_h_cm:.16g}")
print("JOINT_TRANSITION_PROVIDER_SHA256=" + hashlib.sha256(provider_out.read_bytes()).hexdigest())
print("JOINT_TRANSITION_DRIVER_SHA256=" + hashlib.sha256(test_out.read_bytes()).hexdigest())
