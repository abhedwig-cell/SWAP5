#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

SE={1:0.68,2:0.78,3:0.86,4:0.92}
SCHEDULE={
  1:(192,576,"FALL","RISE"),
  2:(192,576,"RISE","FALL"),
  3:(272,576,"FALL","RISE"),
  4:(304,576,"RISE","FALL"),
}

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def block(text:str,pattern:str,replacement:str,label:str)->str:
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1:
        raise SystemExit(f"{label}: expected one block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def initial_block()->str:
    return """  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.68_real64
    case(2); value=0.78_real64
    case(3); value=0.86_real64
    case(4); value=0.92_real64
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
    call require(symbol==SYM_HOLD.or.symbol==SYM_RISE.or.symbol==SYM_FALL,'LAREGW1 C5P valid fresh boundary-only symbol')
  end function history_symbol
"""

def label_block()->str:
    return """  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=3) :: label
    select case(ih)
    case(1); label='P01'
    case(2); label='P02'
    case(3); label='P03'
    case(4); label='P04'
    case default; label='BAD'
    end select
  end function history_label
"""

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5n-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,16))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5n_base.f90"; bm=td/"c5n_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5n_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--temporal-factor",str(a.temporal_factor),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C5N base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    text=block(text,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",
               initial_block(),"fresh initial states")
    text=block(text,r"^  integer function history_symbol\(ih,step\) result\(symbol\).*?^  end function history_symbol\n",
               symbol_block(a.temporal_factor),"fresh history schedule")
    text=block(text,r"^  function history_label\(ih\) result\(label\).*?^  end function history_label\n",
               label_block(),"fresh history labels")
    text=one(text,"label='C5N_BLIND'","label='C5P_BLIND'","split label")
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5N_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5P_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'",
      "completion marker"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5p.reference-materialization.v1",
      "c5n_materializer_sha256":sha256(a.c5n_materializer),
      "source_harness_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "temporal_factor":a.temporal_factor,
      "transaction_dt_day":0.0008/a.temporal_factor,
      "steps_per_history":1024*a.temporal_factor,
      "histories":{
        "P01":{"Se":0.68,"phase1":"FALL","phase1_steps":192,"phase2":"RISE","phase2_steps":384,"hold_steps":448},
        "P02":{"Se":0.78,"phase1":"RISE","phase1_steps":192,"phase2":"FALL","phase2_steps":384,"hold_steps":448},
        "P03":{"Se":0.86,"phase1":"FALL","phase1_steps":272,"phase2":"RISE","phase2_steps":304,"hold_steps":448},
        "P04":{"Se":0.92,"phase1":"RISE","phase1_steps":304,"phase2":"FALL","phase2_steps":272,"hold_steps":448}
      },
      "allowed_geometries":{"R1024":1024,"R2048":2048},
      "profile_output":{"bins":16,"bin_thickness_cm":10.0,"only_observation_windows":True},
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
