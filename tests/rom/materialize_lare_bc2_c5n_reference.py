#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

SE={1:0.70,2:0.80,3:0.90,4:0.75}
# Observation-window phase endpoints. The second endpoint is always 576.
SCHEDULE={
  1:(224,576,"FALL","RISE"),
  2:(288,576,"RISE","FALL"),
  3:(352,576,"FALL","RISE"),
  4:(224,576,"RISE","FALL"),
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

def symbol_block(factor:int)->str:
    rows=[]
    for i in range(1,5):
        first,end,s1,s2=SCHEDULE[i]
        a=first*factor;b=end*factor
        sym1="SYM_FALL" if s1=="FALL" else "SYM_RISE"
        sym2="SYM_FALL" if s2=="FALL" else "SYM_RISE"
        rows.append(f"""    case({i})
      if(step<={a})then; symbol={sym1}
      else if(step<={b})then; symbol={sym2}
      else; symbol=SYM_HOLD; end if""")
    return """  integer function history_symbol(ih,step) result(symbol)
    integer,intent(in) :: ih,step
    select case(ih)
"""+"\n".join(rows)+"""
    case default
      symbol=0
    end select
    call require(symbol==SYM_HOLD.or.symbol==SYM_RISE.or.symbol==SYM_FALL,'LAREGW1 C5N valid fresh boundary-only symbol')
  end function history_symbol
"""

def label_block()->str:
    return """  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=3) :: label
    select case(ih)
    case(1); label='N01'
    case(2); label='N02'
    case(3); label='N03'
    case(4); label='N04'
    case default; label='BAD'
    end select
  end function history_label
"""

def profile_block()->str:
    return """      call require(mod(numnod,16)==0,'LAREGW1 C5N profile geometry divisible by 16')
      if(mod(step,OUTPUT_FACTOR)==0)then
        nodes_per_bin=numnod/16
        do bin=1,16
          lo_node=(bin-1)*nodes_per_bin+1
          hi_node=bin*nodes_per_bin
          bin_theta=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))/10.0_real64
          write(*,'(*(g0))') 'LAREGW1_PROFILE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|OBS_STEP=',step/OUTPUT_FACTOR,'|BIN=',bin,'|THETA=',bin_theta
        end do
      end if
"""

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()
    factor=a.temporal_factor

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5a_base.f90"
        bm=td/"c5a_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C5A base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "integer, parameter :: NHIST=4, NSTEPS=1024",
      f"integer, parameter :: NHIST=4, NSTEPS={1024*factor}\n  integer, parameter :: OUTPUT_FACTOR={factor}",
      "C5N time-grid parameters"
    )
    text=one(
      text,
      "real(real64), parameter :: step_dt=0.0008_real64",
      f"real(real64), parameter :: step_dt={0.0008/factor:.12g}_real64",
      "C5N transaction interval"
    )
    text=one(
      text,
      "call require(any(numnod==[2,16]),'LAREGW1 C4Z geometry is R2 or R16')",
      "call require(any(numnod==[512,1024,2048]),'LAREGW1 C5N geometry is R512/R1024/R2048')",
      "C5N geometry guard"
    )
    text=block(text,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",
               initial_block(),"fresh initial states")
    text=block(text,r"^  integer function history_symbol\(ih,step\) result\(symbol\).*?^  end function history_symbol\n",
               symbol_block(factor),"fresh history schedule")
    text=block(text,r"^  function history_label\(ih\) result\(label\).*?^  end function history_label\n",
               label_block(),"fresh history labels")
    text=one(text,"label='C5A_B14  '","label='C5N_BLIND'","split label")
    text=one(
      text,
      "    integer :: node\n",
      "    integer :: bin,lo_node,hi_node,nodes_per_bin\n    real(real64) :: bin_theta\n",
      "profile output declarations"
    )
    node_pattern=(
      r"\n      do node=1,numnod\n"
      r"        write\(\*,'\(\*\(g0\)\)'\) 'LAREGW1_NODE\|SPLIT=',trim\(split_label\(ih\)\),'\|HISTORY=',trim\(history_label\(ih\)\), &\n"
      r"             '\|STEP=',step,'\|NODE=',node,'\|H=',physical%pressure_head\(node\),'\|THETA=',physical%water_content\(node\)\n"
      r"      end do"
    )
    text,n=re.subn(node_pattern,"\n"+profile_block().rstrip(),text,count=1)
    if n!=1:
        raise SystemExit(f"profile replacement expected one node loop, found {n}")
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5A_B14_DYNAMIC_HEAD_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5N_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'",
      "completion marker"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5n.reference-materialization.v1",
      "source_harness_sha256":sha256(a.source),
      "c5a_materializer_sha256":sha256(a.c5a_materializer),
      "output_sha256":sha256(a.output),
      "temporal_factor":factor,
      "transaction_dt_day":0.0008/factor,
      "steps_per_history":1024*factor,
      "histories":{
        "N01":{"Se":0.70,"phase1":"FALL","phase1_steps":224,"phase2":"RISE","phase2_steps":352,"hold_steps":448},
        "N02":{"Se":0.80,"phase1":"RISE","phase1_steps":288,"phase2":"FALL","phase2_steps":288,"hold_steps":448},
        "N03":{"Se":0.90,"phase1":"FALL","phase1_steps":352,"phase2":"RISE","phase2_steps":224,"hold_steps":448},
        "N04":{"Se":0.75,"phase1":"RISE","phase1_steps":224,"phase2":"FALL","phase2_steps":352,"hold_steps":448}
      },
      "allowed_geometries":{"R512":512,"R1024":1024,"R2048":2048},
      "profile_output":{"bins":16,"bin_thickness_cm":10.0,"only_observation_windows":True},
      "node_output_suppressed":True,
      "material":"B14",
      "bottom_head_multipliers":{"RISE":0.875,"FALL":1.125},
      "reference_retry_policy_changed":False,
      "solver_or_physics_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
