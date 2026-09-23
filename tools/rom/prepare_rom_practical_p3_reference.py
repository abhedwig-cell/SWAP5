#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re

def block(text,pattern,replacement,label):
    rx=re.compile(pattern,re.MULTILINE|re.DOTALL)
    hits=rx.findall(text)
    if len(hits)!=1: raise SystemExit(f"{label}: expected 1 block, found {len(hits)}")
    return rx.sub(replacement,text,count=1)

def one(text,old,new,label):
    n=text.count(old)
    if n!=1: raise SystemExit(f"{label}: expected 1 match, found {n}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    t=a.source.read_text()
    if a.purpose=="SURF_P":
        t=one(t,"integer, parameter :: NHIST=4, NSTEPS=8192\n  integer, parameter :: OUTPUT_FACTOR=8",
              "integer, parameter :: NHIST=2, NSTEPS=1920\n  integer, parameter :: OUTPUT_FACTOR=32","time grid")
        t=one(t,"real(real64), parameter :: step_dt=0.0001_real64",
              "real(real64), parameter :: step_dt=0.03125_real64","step dt")
        t=block(t,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",
"""  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.72_real64
    case(2); value=0.86_real64
    case default; value=-1.0_real64
    end select
  end function initial_se
""","surface initial")
        t=block(t,r"^  pure integer function forcing_kind\(ih\) result\(value\).*?^  end function forcing_kind\n",
"""  pure integer function forcing_kind(ih) result(value)
    integer,intent(in) :: ih
    value=ih
  end function forcing_kind
""","surface forcing kind")
        t=block(t,r"^  pure real\(real64\) function top_multiplier\(kind,step\) result\(value\).*?^  end function top_multiplier\n",
"""  pure real(real64) function top_multiplier(kind,step) result(value)
    integer,intent(in) :: kind,step
    select case(kind)
    case(1)
      if(step<=480)then; value=0.12_real64
      else if(step<=960)then; value=-0.08_real64
      else if(step<=1440)then; value=0.06_real64
      else; value=-0.04_real64; end if
    case(2)
      if(step<=640)then; value=-0.06_real64
      else if(step<=960)then; value=0.10_real64
      else if(step<=1600)then; value=-0.03_real64
      else; value=0.08_real64; end if
    case default
      value=huge(0.0_real64)
    end select
  end function top_multiplier
""","surface forcing schedule")
        t=block(t,r"^  function case_label\(ih\) result\(label\).*?^  end function case_label\n",
"""  function case_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=48) :: label
    select case(ih)
    case(1); label='SD01'
    case(2); label='SD02'
    case default; label='BAD'
    end select
  end function case_label
""","surface labels")
        t=block(t,r"^  subroutine configure_case\(ih,step,h0,k0,qeq,p,forcing\).*?^  end subroutine configure_case\n",
"""  subroutine configure_case(ih,step,h0,k0,qeq,p,forcing)
    integer,intent(in) :: ih,step
    real(real64),intent(in) :: h0,k0,qeq
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64) :: delta
    delta=top_multiplier(forcing_kind(ih),step)
    p%total_balance_tolerance=original_total_tol
    p%bottom_mode=2
    forcing%top_head=0.0_real64
    forcing%top_flux=-(k0+delta)
    forcing%bottom_flux=qeq
    forcing%bottom_head=h0
  end subroutine configure_case
""","surface configure")
    else:
        t=one(t,"integer, parameter :: NHIST=4, NSTEPS=8192\n  integer, parameter :: OUTPUT_FACTOR=8",
              "integer, parameter :: NHIST=2, NSTEPS=1920\n  integer, parameter :: OUTPUT_FACTOR=32","time grid")
        t=one(t,"real(real64), parameter :: step_dt=0.0001_real64",
              "real(real64), parameter :: step_dt=0.03125_real64","step dt")
        t=block(t,r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",
"""  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.72_real64
    case(2); value=0.88_real64
    case default; value=-1.0_real64
    end select
  end function initial_se
""","gw initial")
        t=block(t,r"^  integer function history_symbol\(ih,step\) result\(symbol\).*?^  end function history_symbol\n",
"""  integer function history_symbol(ih,step) result(symbol)
    integer,intent(in) :: ih,step
    select case(ih)
    case(1)
      if(step<=640)then; symbol=SYM_RISE
      else if(step<=1280)then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case(2)
      if(step<=480)then; symbol=SYM_FALL
      else if(step<=1440)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case default
      symbol=0
    end select
  end function history_symbol
""","gw schedule")
        t=block(t,r"^  function history_label\(ih\) result\(label\).*?^  end function history_label\n",
"""  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=3) :: label
    select case(ih)
    case(1); label='D01'
    case(2); label='D02'
    case default; label='BAD'
    end select
  end function history_label
""","gw labels")
        t=t.replace("forcing%bottom_head=0.90_real64*h0","forcing%bottom_head=0.97_real64*h0")
        t=t.replace("forcing%bottom_head=1.10_real64*h0","forcing%bottom_head=1.03_real64*h0")
    a.output.write_text(t)
    print(f"ROM_PRACTICAL_P3_REFERENCE_{a.purpose}=PASS")
if __name__=="__main__": main()
