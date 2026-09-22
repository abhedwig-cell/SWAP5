#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re

SE={1:0.68,2:0.82,3:0.73,4:0.90}
SCHEDULE={
  1:(192,512,"WET","DRY"),
  2:(192,512,"DRY","WET"),
  3:(320,512,"WET","DRY"),
  4:(320,512,"DRY","WET"),
}

def sha256(p:pathlib.Path)->str:
    return hashlib.sha256(p.read_bytes()).hexdigest()

def one(t,o,n,label):
    c=t.count(o)
    if c!=1: raise SystemExit(f"{label}: expected one match, found {c}")
    return t.replace(o,n,1)

def block(t,pat,repl,label):
    rx=re.compile(pat,re.MULTILINE|re.DOTALL)
    if len(rx.findall(t))!=1: raise SystemExit(f"{label}: expected one block")
    return rx.sub(repl,t,count=1)

def initial_block():
    return """  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.68_real64
    case(2); value=0.82_real64
    case(3); value=0.73_real64
    case(4); value=0.90_real64
    case default; value=-1.0_real64
    end select
  end function initial_se
"""

def bottom_block():
    return """  pure integer function bottom_kind(ih) result(value)
    integer,intent(in) :: ih
    if(ih>=1.and.ih<=4)then
      value=BOTTOM_FIXED_FLUX
    else
      value=-1
    end if
  end function bottom_kind
"""

def forcing_kind_block():
    return """  pure integer function forcing_kind(ih) result(value)
    integer,intent(in) :: ih
    if(ih>=1.and.ih<=4)then
      value=ih
    else
      value=-1
    end if
  end function forcing_kind
"""

def multiplier_block(factor):
    rows=[]
    for ih in range(1,5):
        first,end,s1,s2=SCHEDULE[ih]
        m1="1.10_real64" if s1=="WET" else "0.90_real64"
        m2="1.10_real64" if s2=="WET" else "0.90_real64"
        rows.append(f"""    case({ih})
      if(step<={first*factor})then; value={m1}
      else if(step<={end*factor})then; value={m2}
      else; value=1.0_real64; end if""")
    return """  pure real(real64) function top_multiplier(kind,step) result(value)
    integer,intent(in) :: kind,step
    select case(kind)
"""+chr(10).join(rows)+"""
    case default
      value=-1.0_real64
    end select
  end function top_multiplier
"""

def case_label_block():
    return """  function case_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=48) :: label
    select case(ih)
    case(1); label='S01'
    case(2); label='S02'
    case(3); label='S03'
    case(4); label='S04'
    case default; label='BAD'
    end select
  end function case_label
"""

def forcing_label_block():
    return """  pure function forcing_label(kind) result(label)
    integer,intent(in) :: kind
    character(len=20) :: label
    select case(kind)
    case(1); label='WET_DRY_192_320'
    case(2); label='DRY_WET_192_320'
    case(3); label='WET_DRY_320_192'
    case(4); label='DRY_WET_320_192'
    case default; label='UNKNOWN'
    end select
  end function forcing_label
"""

def configure_block():
    return """  subroutine configure_case(ih,step,h0,k0,qeq,p,forcing)
    integer,intent(in) :: ih,step
    real(real64),intent(in) :: h0,k0,qeq
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64) :: multiplier
    multiplier=top_multiplier(forcing_kind(ih),step)
    call require(multiplier>0.0_real64,'LAREDYN0R ROMPURP_P1_SURFACE valid top multiplier')
    p%total_balance_tolerance=original_total_tol
    p%bottom_mode=2
    forcing%top_head=0.0_real64
    forcing%top_flux=-multiplier*k0
    forcing%bottom_flux=qeq
    forcing%bottom_head=h0
  end subroutine configure_case
"""

def profile_loop():
    return """      if(mod(step,OUTPUT_FACTOR)==0)then
        call require(mod(numnod,16)==0,'LAREDYN0R ROMPURP_P1_SURFACE geometry divisible by 16')
        nodes_per_bin=numnod/16
        do bin=1,16
          lo_node=(bin-1)*nodes_per_bin+1
          hi_node=bin*nodes_per_bin
          bin_theta=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))/10.0_real64
          write(*,'(*(g0))') 'LAREDYN0R_PROFILE|CASE=',trim(case_label(ih)),'|STEP=',step, &
               '|OBS_STEP=',step/OUTPUT_FACTOR,'|BIN=',bin,'|THETA=',bin_theta
        end do
      end if"""

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    factor=a.temporal_factor
    text=a.source.read_text()

    text=one(text,"integer, parameter :: NHIST=24, NSTEPS=1024",
             f"integer, parameter :: NHIST=4, NSTEPS={1024*factor}\n  integer, parameter :: OUTPUT_FACTOR={factor}","time grid")
    text=one(text,"real(real64), parameter :: step_dt=0.0008_real64",
             f"real(real64), parameter :: step_dt={0.0008/factor:.12g}_real64","dt")
    text=block(text,r"^  pure integer function bottom_kind\(ih\) result\(value\).*?^  end function bottom_kind\n",bottom_block(),"bottom kind")
    text=block(text,r"^  pure integer function forcing_kind\(ih\) result\(value\).*?^  end function forcing_kind\n",forcing_kind_block(),"forcing kind")
    text=block(text,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",initial_block(),"initial")
    text=block(text,r"^  pure real\(real64\) function top_multiplier\(kind,step\) result\(value\).*?^  end function top_multiplier\n",multiplier_block(factor),"top multiplier")
    text=block(text,r"^  function case_label\(ih\) result\(label\).*?^  end function case_label\n",case_label_block(),"case label")
    text=block(text,r"^  pure function forcing_label\(kind\) result\(label\).*?^  end function forcing_label\n",forcing_label_block(),"forcing label")
    text=block(text,r"^  subroutine configure_case\(ih,step,h0,k0,qeq,p,forcing\).*?^  end subroutine configure_case\n",configure_block(),"configure")

    text=one(text,"    real(real64) :: total\n    integer :: node\n",
             "    real(real64) :: total,bin_theta\n    integer :: bin,lo_node,hi_node,nodes_per_bin\n","emit decl")
    pat=(r"\n      do node=1,numnod\n"
         r"        write\(\*,'\(\*\(g0\)\)'\) 'LAREDYN0R_NODE\|CASE=',trim\(case_label\(ih\)\),'\|STEP=',step,'\|NODE=',node, &\n"
         r"             '\|Z=',z\(node\),'\|DZ=',dz\(node\),'\|H=',physical%pressure_head\(node\),'\|THETA=',physical%water_content\(node\)\n"
         r"      end do")
    text,n=re.subn(pat,"\n"+profile_loop(),text,count=1)
    if n!=1: raise SystemExit(f"profile replacement found {n}")

    text=one(text,"  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
             "  write(*,'(A)') 'LAREDYN0R_ROMPURP_P1_SURFACE_REFERENCE_GENERATED=TRUE'\n  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'","marker")
    a.output.write_text(text)

    m={
      "schema":"swap5.rom-purpose.p1.surface-reference-materialization.v1",
      "source_sha256":sha256(a.source),"output_sha256":sha256(a.output),
      "material":a.material,"temporal_factor":factor,
      "transaction_dt_day":0.0008/factor,"steps_per_history":1024*factor,
      "history_count":4,
      "histories":{
        "S01":{"Se":0.68,"phase1":"WET","phase1_observations":192,"phase2":"DRY","phase2_observations":320,"hold_observations":512},
        "S02":{"Se":0.82,"phase1":"DRY","phase1_observations":192,"phase2":"WET","phase2_observations":320,"hold_observations":512},
        "S03":{"Se":0.73,"phase1":"WET","phase1_observations":320,"phase2":"DRY","phase2_observations":192,"hold_observations":512},
        "S04":{"Se":0.90,"phase1":"DRY","phase1_observations":320,"phase2":"WET","phase2_observations":192,"hold_observations":512}
      },
      "top_flux_multipliers":{"WET":1.10,"DRY":0.90,"HOLD":1.0},
      "bottom_boundary":"FIXED_GRAVITY_EQUILIBRIUM_FLUX","bottom_mode":2,
      "bottom_flux_rule":"forcing%bottom_flux=qeq for all phases",
      "root_sink_zero":True,
      "profile_output":{"bins":16,"bin_thickness_cm":10.0,"only_observation_windows":True},
      "node_output_suppressed":True,
      "retry_policy_changed":False,"solver_or_physics_changed":False,"response_based":False
    }
    a.manifest.write_text(json.dumps(m,indent=2,sort_keys=True)+"\n")
    print(json.dumps(m,sort_keys=True))
if __name__=="__main__": main()
