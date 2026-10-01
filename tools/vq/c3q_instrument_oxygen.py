#!/usr/bin/env python3
"""Reversible diagnostic instrumentation for exact B1.11 oxygenstress.f90."""
from __future__ import annotations
import argparse, hashlib
from pathlib import Path

SOURCE_SHA256="8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87"
BEGIN=b"! C3Q_TRACE_BEGIN\r\n"; END=b"! C3Q_TRACE_END\r\n"

def sha(b:bytes)->str: return hashlib.sha256(b).hexdigest()
def once(data,old,new,label):
    n=data.count(old)
    if n!=1: raise ValueError(f"{label}: expected one anchor, found {n}")
    return data.replace(old,new,1)

def instrument(source:bytes)->bytes:
    if sha(source)!=SOURCE_SHA256: raise ValueError(f"source identity mismatch:{sha(source)}")
    use_anchor=b"      use MOD_SoilTemperature,   only: tsoil\r\n"
    use_extra=use_anchor+BEGIN+(
      b"      use plant_interface, only: c3q_q10_root=>q10_root, c3q_c_mroot=>c_mroot, c3q_f_senes=>f_senes\r\n"
      b"      use MOD_cropdevelopment, only: c3q_rootradius_m=>rootradius_m, c3q_q10_micro=>q10_microbial, c3q_specific_humus=>specific_resp_humus\r\n"
      b"      use O2_pars, only: c3q_shape_micro=>shape_factor_microbialr, c3q_shape_root=>shape_factor_rootr\r\n"
    )+END
    out=once(source,use_anchor,use_extra,"trace-input-imports")
    decl_anchor=b"      logical                    :: ini = .TRUE.\r\n"
    decl=decl_anchor+BEGIN+(
      b"      integer, save             :: c3q_trace_unit = -1\r\n"
      b"      integer, save             :: c3q_call_index = 0\r\n"
      b"      logical, save             :: c3q_trace_header = .FALSE.\r\n"
      b"      logical, save             :: c3q_trace_open = .FALSE.\r\n"
    )+END
    out=once(out,decl_anchor,decl,"declaration")

    sat_anchor=b"         c_top(node+1) = C_macro\r\n      else"
    sat=(
      b"         c_top(node+1) = C_macro\r\n"+BEGIN+
      b"         call c3q_write_trace('SATURATED',node,matric_potential,theta0,gas_filled_porosity,soil_temp,max_resp_factor,0.d0,0.d0,0.d0,0.d0,c_macro,0.d0,resp_factor,rwu_factor,c3q_c_mroot,w_root,w_root_z0,c3q_f_senes,c3q_q10_root,d_o2inwater,d_root,perc_org_mat,soil_density,depth,c3q_shape_micro,c3q_shape_root,c3q_rootradius_m,bunsencoeff,c3q_q10_micro,c3q_specific_humus)\r\n"+
      END+b"      else"
    )
    out=once(out,sat_anchor,sat,"saturated-route")

    physical_anchor=(
      b"          if (rwu_factor < 0.d0) then\r\n"
      b"              rwu_factor = 0.d0\r\n"
      b"          end if\r\n"
      b"      \r\n"
      b"      end if !if (gas_filled_porosity < 1.0d-6) !RB20131216 goto removed\r\n"
    )
    physical=(
      b"          if (rwu_factor < 0.d0) then\r\n"
      b"              rwu_factor = 0.d0\r\n"
      b"          end if\r\n"+BEGIN+
      b"          call c3q_write_trace('PHYSICAL',node,matric_potential,theta0,gas_filled_porosity,soil_temp,max_resp_factor,waterfilm_thickness,d_soil,r_microbial_z0,ctopnode,c_macro,c_min_micro,resp_factor,rwu_factor,c3q_c_mroot,w_root,w_root_z0,c3q_f_senes,c3q_q10_root,d_o2inwater,d_root,perc_org_mat,soil_density,depth,c3q_shape_micro,c3q_shape_root,c3q_rootradius_m,bunsencoeff,c3q_q10_micro,c3q_specific_humus)\r\n"+
      END+
      b"      \r\n"
      b"      end if !if (gas_filled_porosity < 1.0d-6) !RB20131216 goto removed\r\n"
    )
    out=once(out,physical_anchor,physical,"physical-route")

    contains_anchor=b"   contains\r\n   \r\n   subroutine calc_ini_pars (numnod)"
    helper=(
      b"   contains\r\n"+BEGIN+
      b"   subroutine c3q_write_trace(route,node,mp,th,gfp,temp,maxrf,wft,ds,rm,ctop,cmac,cmic,rf,rwu,cmr,wr,wr0,fs,q10r,dw,dr,om,bd,dep,sm,sr,rr,bc,q10m,srh)\r\n"
      b"      character(len=*), intent(in) :: route\r\n"
      b"      integer, intent(in) :: node\r\n"
      b"      real(8), intent(in) :: mp,th,gfp,temp,maxrf,wft,ds,rm,ctop,cmac,cmic,rf,rwu,cmr,wr,wr0,fs,q10r,dw,dr,om,bd,dep,sm,sr,rr,bc,q10m,srh\r\n"
      b"      c3q_call_index=c3q_call_index+1\r\n"
      b"      if (c3q_call_index > 500 .and. trim(route) == 'SATURATED') return\r\n"
      b"      if (c3q_call_index > 500 .and. trim(route) == 'PHYSICAL' .and. rwu >= 0.999999d0) return\r\n"
      b"      if (.not.c3q_trace_open) then\r\n"
      b"         open(newunit=c3q_trace_unit,file='c3q_oxygen_trace.csv',status='replace',action='write')\r\n"
      b"         c3q_trace_open=.TRUE.\r\n"
      b"      end if\r\n"
      b"      if (.not.c3q_trace_header) then\r\n"
      b"         write(c3q_trace_unit,'(a)') 'call_index,route,node,matric_potential_pa,theta,gas_filled_porosity,soil_temp_k,max_resp_factor,waterfilm_thickness_m,d_soil,r_microbial_z0,ctopnode,c_macro,c_min_micro,resp_factor,rwu_factor,c_mroot,w_root,w_root_z0,f_senes,q10_root,d_o2inwater,d_root,perc_org_mat,soil_density,depth,shape_micro,shape_root,rootradius_m,bunsencoeff,q10_microbial,specific_resp_humus'\r\n"
      b"         c3q_trace_header=.TRUE.\r\n"
      b"      end if\r\n"
      b"      write(c3q_trace_unit,'(i0,\",\",a,\",\",i0,29(\",\",es25.16e3))') c3q_call_index,trim(route),node,mp,th,gfp,temp,maxrf,wft,ds,rm,ctop,cmac,cmic,rf,rwu,cmr,wr,wr0,fs,q10r,dw,dr,om,bd,dep,sm,sr,rr,bc,q10m,srh\r\n"
      b"   end subroutine c3q_write_trace\r\n"+END+
      b"   \r\n   subroutine calc_ini_pars (numnod)"
    )
    out=once(out,contains_anchor,helper,"helper")
    return out

def strip_trace(data:bytes)->bytes:
    while BEGIN in data:
        a=data.index(BEGIN); b=data.index(END,a)+len(END); data=data[:a]+data[b:]
    return data

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("source",type=Path); ap.add_argument("output",type=Path); a=ap.parse_args()
    original=a.source.read_bytes(); traced=instrument(original)
    if strip_trace(traced)!=original: raise SystemExit("C3Q_STRIP_RESTORES_ORIGINAL=FAIL")
    a.output.write_bytes(traced)
    print("C3Q_INSTRUMENTATION=PASS"); print("C3Q_STRIP_RESTORES_ORIGINAL=PASS")
    print(f"C3Q_ORIGINAL_SHA256={sha(original)}"); print(f"C3Q_INSTRUMENTED_SHA256={sha(traced)}")
if __name__=="__main__": main()
