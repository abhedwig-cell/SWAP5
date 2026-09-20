#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re


SE={1:0.70,2:0.80,3:0.90,4:0.75}
SCHEDULE={
    1:(192,512,"WET","DRY"),
    2:(192,512,"DRY","WET"),
    3:(320,512,"WET","DRY"),
    4:(320,512,"DRY","WET"),
}


def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)


def block(text:str,pattern:str,replacement:str,label:str)->str:
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)


def initial_block()->str:
    return """  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.70_real64
    case(2); value=0.80_real64
    case(3); value=0.90_real64
    case(4); value=0.75_real64
    case default; value=-1.0_real64
    end select
  end function initial_se
"""


def bottom_block()->str:
    return """  pure integer function bottom_kind(ih) result(value)
    integer,intent(in) :: ih
    call require(ih>=1.and.ih<=4,'LAREDYN0R C6M valid history for free drainage')
    value=BOTTOM_FREE_DRAINAGE
  end function bottom_kind
"""


def forcing_kind_block()->str:
    return """  pure integer function forcing_kind(ih) result(value)
    integer,intent(in) :: ih
    call require(ih>=1.and.ih<=4,'LAREDYN0R C6M valid forcing history')
    value=ih
  end function forcing_kind
"""


def multiplier_block(factor:int)->str:
    rows=[]
    for ih in range(1,5):
        first,end,s1,s2=SCHEDULE[ih]
        a=first*factor
        b=end*factor
        m1="1.125_real64" if s1=="WET" else "0.875_real64"
        m2="1.125_real64" if s2=="WET" else "0.875_real64"
        rows.append(f"""    case({ih})
      if(step<={a})then; value={m1}
      else if(step<={b})then; value={m2}
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


def label_block()->str:
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


def forcing_label_block()->str:
    return """  pure function forcing_label(kind) result(label)
    integer,intent(in) :: kind
    character(len=16) :: label
    select case(kind)
    case(1); label='WET_DRY_192_320'
    case(2); label='DRY_WET_192_320'
    case(3); label='WET_DRY_320_192'
    case(4); label='DRY_WET_320_192'
    case default; label='UNKNOWN'
    end select
  end function forcing_label
"""


def profile_loop()->str:
    return """      if(mod(step,OUTPUT_FACTOR)==0)then
        call require(mod(numnod,16)==0,'LAREDYN0R C6M geometry divisible by 16')
        nodes_per_bin=numnod/16
        do bin=1,16
          lo_node=(bin-1)*nodes_per_bin+1
          hi_node=bin*nodes_per_bin
          bin_theta=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))/10.0_real64
          write(*,'(*(g0))') 'LAREDYN0R_PROFILE|CASE=',trim(case_label(ih)),'|STEP=',step, &
               '|OBS_STEP=',step/OUTPUT_FACTOR,'|BIN=',bin,'|THETA=',bin_theta
        end do
      end if"""


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    factor=a.temporal_factor
    text=a.source.read_text(encoding="utf-8")

    text=one(
        text,
        "integer, parameter :: NHIST=24, NSTEPS=1024",
        f"integer, parameter :: NHIST=4, NSTEPS={1024*factor}\n  integer, parameter :: OUTPUT_FACTOR={factor}",
        "time-grid parameters"
    )
    text=one(
        text,
        "real(real64), parameter :: step_dt=0.0008_real64",
        f"real(real64), parameter :: step_dt={0.0008/factor:.12g}_real64",
        "transaction dt"
    )
    text=block(
        text,
        r"^  pure integer function bottom_kind\(ih\) result\(value\).*?^  end function bottom_kind\n",
        bottom_block(),
        "bottom kind"
    )
    text=block(
        text,
        r"^  pure integer function forcing_kind\(ih\) result\(value\).*?^  end function forcing_kind\n",
        forcing_kind_block(),
        "forcing kind"
    )
    text=block(
        text,
        r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",
        initial_block(),
        "initial Se"
    )
    text=block(
        text,
        r"^  pure real\(real64\) function top_multiplier\(kind,step\) result\(value\).*?^  end function top_multiplier\n",
        multiplier_block(factor),
        "top multiplier"
    )
    text=block(
        text,
        r"^  function case_label\(ih\) result\(label\).*?^  end function case_label\n",
        label_block(),
        "case label"
    )
    text=block(
        text,
        r"^  pure function forcing_label\(kind\) result\(label\).*?^  end function forcing_label\n",
        forcing_label_block(),
        "forcing label"
    )

    text=one(
        text,
        "    real(real64) :: total\n    integer :: node\n",
        "    real(real64) :: total,bin_theta\n    integer :: bin,lo_node,hi_node,nodes_per_bin\n",
        "emit declarations"
    )
    node_pattern=(
      r"\n      do node=1,numnod\n"
      r"        write\(\*,'\(\*\(g0\)\)'\) 'LAREDYN0R_NODE\|CASE=',trim\(case_label\(ih\)\),'\|STEP=',step,'\|NODE=',node, &\n"
      r"             '\|Z=',z\(node\),'\|DZ=',dz\(node\),'\|H=',physical%pressure_head\(node\),'\|THETA=',physical%water_content\(node\)\n"
      r"      end do"
    )
    text,n=re.subn(node_pattern,"\n"+profile_loop(),text,count=1)
    if n!=1:
        raise SystemExit(f"profile replacement expected one node loop, found {n}")

    text=one(
        text,
        "  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
        "  write(*,'(A)') 'LAREDYN0R_C6M_SURFACE_REFERENCE_GENERATED=TRUE'\n  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'",
        "completion marker"
    )

    # Free-drainage cases already fail closed in the source harness: no DYN0A fallback
    # is admitted when bottom_mode is not the fixed-flux mode.
    a.output.write_text(text,encoding="utf-8")
    manifest={
      "schema":"swap5.lare.bc2.c6m.reference-materialization.v1",
      "source_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "material":a.material,
      "temporal_factor":factor,
      "transaction_dt_day":0.0008/factor,
      "steps_per_history":1024*factor,
      "history_count":4,
      "histories":{
        "S01":{"Se":0.70,"phase1":"WET","phase1_observations":192,"phase2":"DRY","phase2_observations":320,"hold_observations":512},
        "S02":{"Se":0.80,"phase1":"DRY","phase1_observations":192,"phase2":"WET","phase2_observations":320,"hold_observations":512},
        "S03":{"Se":0.90,"phase1":"WET","phase1_observations":320,"phase2":"DRY","phase2_observations":192,"hold_observations":512},
        "S04":{"Se":0.75,"phase1":"DRY","phase1_observations":320,"phase2":"WET","phase2_observations":192,"hold_observations":512}
      },
      "top_flux_multipliers":{"WET":1.125,"DRY":0.875,"HOLD":1.0},
      "bottom_boundary":"FREE_DRAINAGE",
      "root_sink_zero":True,
      "profile_output":{"bins":16,"bin_thickness_cm":10.0,"only_observation_windows":True},
      "node_output_suppressed":True,
      "reference_retry_policy_changed":False,
      "solver_or_physics_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    print(json.dumps(manifest,sort_keys=True))
    return 0


if __name__=="__main__":
    raise SystemExit(main())
