#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re

def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f"{label}: expected exactly one source match, found {text.count(old)}")
    return text.replace(old, new, 1)

def replace_block(text: str, pattern: str, replacement: str, label: str) -> str:
    rx = re.compile(pattern, re.MULTILINE | re.DOTALL)
    hits = rx.findall(text)
    if len(hits) != 1:
        raise SystemExit(f"{label}: expected exactly one block, found {len(hits)}")
    return rx.sub(replacement, text, count=1)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, type=pathlib.Path)
    ap.add_argument("--output", required=True, type=pathlib.Path)
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    a = ap.parse_args()

    text = a.source.read_text(encoding="utf-8")
    text = replace_once(text, "integer, parameter :: NHIST=6, NSTEPS=1024",
                        "integer, parameter :: NHIST=4, NSTEPS=1024", "history count")
    text = replace_once(text, "call require(numnod==16,'LAREGW1 geometry frozen at 16 nodes')",
                        "call require(any(numnod==[2,16]),'LAREGW1 C4Y geometry is R2 or R16')", "geometry guard")

    metrics = """  subroutine metrics_from_physical(physical,total,upper,lower)
    type(fmr_b110_physical_state_t),intent(in) :: physical
    real(real64),intent(out) :: total,upper,lower
    real(real64) :: ztop,zbot,w
    integer :: node
    total=sum(physical%water_content(1:numnod)*dz(1:numnod))
    upper=0.0_real64;lower=0.0_real64;ztop=0.0_real64
    do node=1,numnod
      zbot=ztop+dz(node)
      w=max(0.0_real64,min(zbot,80.0_real64)-max(ztop,0.0_real64))
      upper=upper+physical%water_content(node)*w
      w=max(0.0_real64,min(zbot,160.0_real64)-max(ztop,80.0_real64))
      lower=lower+physical%water_content(node)*w
      ztop=zbot
    end do
    call require(ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower),'LAREGW1 finite primary outputs')
  end subroutine metrics_from_physical
"""
    text = replace_block(text, r"^  subroutine metrics_from_physical\(physical,total,upper,lower\).*?^  end subroutine metrics_from_physical\n",
                         metrics, "metrics")

    initial_se = """  pure real(real64) function initial_se(ih) result(value)
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
    text = replace_block(text, r"^  pure real\(real64\) function initial_se\(ih\) result\(value\).*?^  end function initial_se\n",
                         initial_se, "initial_se")

    history_symbol = """  integer function history_symbol(ih,step) result(symbol)
    integer,intent(in) :: ih,step
    select case(ih)
    case(1)
      if(step<=192)then; symbol=SYM_FALL
      else if(step<=576)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(2)
      if(step<=192)then; symbol=SYM_RISE
      else if(step<=576)then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case(3)
      if(step<=384)then; symbol=SYM_FALL
      else if(step<=576)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(4)
      if(step<=384)then; symbol=SYM_RISE
      else if(step<=576)then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case default
      symbol=0
    end select
    call require(symbol==SYM_HOLD.or.symbol==SYM_RISE.or.symbol==SYM_FALL,'LAREGW1 C4Y valid boundary-only symbol')
  end function history_symbol
"""
    text = replace_block(text, r"^  integer function history_symbol\(ih,step\) result\(symbol\).*?^  end function history_symbol\n",
                         history_symbol, "history_symbol")

    history_label = """  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=3) :: label
    select case(ih)
    case(1); label='Y01'
    case(2); label='Y02'
    case(3); label='Y03'
    case(4); label='Y04'
    case default; label='BAD'
    end select
  end function history_label
"""
    text = replace_block(text, r"^  function history_label\(ih\) result\(label\).*?^  end function history_label\n",
                         history_label, "history_label")

    split_label = """  pure function split_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=9) :: label
    if(ih>=1.and.ih<=NHIST)then
      label='C4Y_BLIND'
    else
      label='INVALID  '
    end if
  end function split_label
"""
    text = replace_block(text, r"^  pure function split_label\(ih\) result\(label\).*?^  end function split_label\n",
                         split_label, "split_label")

    text = replace_once(
        text,
        "case(SYM_RISE)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=0.75_real64*h0\n"
        "    case(SYM_FALL)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=1.25_real64*h0",
        "case(SYM_RISE)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=0.875_real64*h0\n"
        "    case(SYM_FALL)\n      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=1.125_real64*h0",
        "dynamic head factors",
    )
    text = replace_once(text, "write(*,'(A)') 'LAREGW1_B14_MATERIAL_TRANSFER_GENERATED=FALSE'",
                        "write(*,'(A)') 'LAREGW1_C4Y_BLIND_DYNAMIC_HEAD_GENERATED=TRUE'", "completion metadata")

    a.output.write_text(text, encoding="utf-8")
    manifest = {
        "schema": "swap5.lare.bc2.c4y.materialization.v1",
        "source_sha256": sha256(a.source),
        "output_sha256": sha256(a.output),
        "changes": [
            "six exposed BC1 histories replaced by four response-blind Y01-Y04 histories",
            "initial effective saturations frozen at 0.70,0.80,0.90,0.75",
            "head multipliers frozen at 0.875 and 1.125 instead of exposed 0.75 and 1.25",
            "timings frozen at 192/576 or 384/576 steps",
            "top forcing remains gravity-consistent qeq for every history",
            "geometry guard extended to R2 and R16 only",
            "0-80/80-160 diagnostics made geometric for R2/R16"
        ],
        "solver_or_physics_changed": False,
        "reference_numerical_policy_changed": False,
        "response_based": False
    }
    a.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps(manifest, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
