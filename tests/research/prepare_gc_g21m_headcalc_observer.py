from __future__ import annotations
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/"src"/"legacy"/"b1_10_port"/"headcalc.f90"
TARGET=ROOT/"tests"/"fgc"/".g21m_headcalc.f90"
PIN="3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55"

def require(cond:bool,msg:str)->None:
    if not cond:
        raise SystemExit(msg)

def blob_sha(path:Path)->str:
    return subprocess.check_output(["git","hash-object",str(path.relative_to(ROOT))],cwd=ROOT,text=True).strip()

def main()->None:
    require(blob_sha(SOURCE)==PIN,"G21M pinned HeadCalc blob drift")
    text=SOURCE.read_text()
    require("g21m_record_residual_snapshot" not in text,"G21M observer already present in production HeadCalc")
    use_anchor="   use MOD_frost,          only: rfcp\n"
    require(text.count(use_anchor)==1,"G21M HeadCalc use anchor drift")
    text=text.replace(use_anchor,use_anchor+
        "   use mod_gc_g21m_residual_observer, only: g21m_record_residual_snapshot\n",1)
    calc_anchor="""         sump = 0.5d0 * dot_product(fsi_ws%residual(1:NN), fsi_ws%residual(1:NN))
         sum1 = sum(fsi_ws%residual(1:NN))
         Fmax = maxval(dabs(fsi_ws%residual(1:NN)))
"""
    require(text.count(calc_anchor)==1,"G21M HeadCalc residual-calculation anchor drift")
    insert=calc_anchor+"""         call g21m_record_residual_snapshot(fsi_ws%residual(1:NN), sum1, Fmax, solver_numbit, iBackTr, &
              NN == 4 .and. swbotb == 5 .and. swmacro == 0, &
              (state%theta(4)-state%thetm1(4))*matrix_fraction(4)*grid_dz(4)/dt, &
              fsi_ws%sink(4), -fsi_ws%source(4), root_sink_term(4), &
              -state%kmean(4)*fsi_ws%head_gradient(4), state%kmean(5)*fsi_ws%head_gradient(5))
"""
    text=text.replace(calc_anchor,insert,1)
    TARGET.write_text(text)
    print("GC_FIXED_INTERFACE_G21M_PINNED_HEADCALC=PASS")
    print("GC_FIXED_INTERFACE_G21M_TEMP_HEADCALC_PREPARED=PASS")

if __name__=="__main__":
    main()
