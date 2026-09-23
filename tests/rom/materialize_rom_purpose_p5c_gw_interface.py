#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,subprocess,sys,tempfile

def one(text,old,new,label):
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--temporal-factor",required=True,type=int,choices=(8,))
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td); base=td/"p5cgw.f90"; bm=td/"p5cgw.json"
        subprocess.run([
          sys.executable,"tests/rom/materialize_rom_purpose_p5c_gw_reference.py",
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),"--material",a.material,
          "--temporal-factor",str(a.temporal_factor),
          "--output",str(base),"--manifest",str(bm)
        ],check=True)
        text=base.read_text()
        m=json.loads(bm.read_text())

    old_decl="""    real(real64) :: total,upper,lower
    integer :: bin,lo_node,hi_node,nodes_per_bin
    real(real64) :: bin_theta
"""
    new_decl="""    real(real64) :: total,upper,lower
    integer :: bin,lo_node,hi_node,nodes_per_bin
    integer :: n25,n125,i_prev,i_bottom,i_half2,i
    real(real64) :: bin_theta,theta_prev,theta_bottom,theta_half1,theta_half2
    real(real64) :: depth_cm,center_cm,moment_num,moment_den,h_slope
    real(real64) :: h_fine_bottom,theta_fine_bottom,face_distance_cm
"""
    text=one(text,old_decl,new_decl,"P5C declarations")

    old="""      call require(mod(numnod,16)==0,'LAREGW1 ROMPURP_P5C_GW profile geometry divisible by 16')
      if(mod(step,OUTPUT_FACTOR)==0)then
        nodes_per_bin=numnod/16
        do bin=1,16
          lo_node=(bin-1)*nodes_per_bin+1
          hi_node=bin*nodes_per_bin
          bin_theta=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))/10.0_real64
          write(*,'(*(g0))') 'LAREGW1_PROFILE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|OBS_STEP=',step/OUTPUT_FACTOR,'|BIN=',bin,'|THETA=',bin_theta
        end do
      end if"""
    new="""      call require(mod(numnod,16)==0,'LAREGW1 ROMPURP_P5C_GW profile geometry divisible by 16')
      call require(mod(numnod,128)==0,'LAREGW1 ROMPURP_P5C diagnostic geometry divisible by 128')
      if(mod(step,OUTPUT_FACTOR)==0)then
        nodes_per_bin=numnod/16
        do bin=1,16
          lo_node=(bin-1)*nodes_per_bin+1
          hi_node=bin*nodes_per_bin
          bin_theta=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))/10.0_real64
          write(*,'(*(g0))') 'LAREGW1_PROFILE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
               '|STEP=',step,'|OBS_STEP=',step/OUTPUT_FACTOR,'|BIN=',bin,'|THETA=',bin_theta
        end do
        n25=numnod/64
        n125=numnod/128
        i_bottom=numnod-n25+1
        i_prev=numnod-2*n25+1
        i_half2=numnod-n125+1
        theta_prev=sum(physical%water_content(i_prev:i_bottom-1)*dz(i_prev:i_bottom-1))/2.5_real64
        theta_bottom=sum(physical%water_content(i_bottom:numnod)*dz(i_bottom:numnod))/2.5_real64
        theta_half1=sum(physical%water_content(i_bottom:i_half2-1)*dz(i_bottom:i_half2-1))/1.25_real64
        theta_half2=sum(physical%water_content(i_half2:numnod)*dz(i_half2:numnod))/1.25_real64
        center_cm=158.75_real64
        moment_num=0.0_real64
        moment_den=0.0_real64
        do i=i_bottom,numnod
          depth_cm=sum(dz(1:i))-0.5_real64*dz(i)
          moment_num=moment_num+(depth_cm-center_cm)*physical%pressure_head(i)*dz(i)
          moment_den=moment_den+(depth_cm-center_cm)*(depth_cm-center_cm)*dz(i)
        end do
        call require(moment_den>0.0_real64,'LAREGW1 ROMPURP_P5C positive head moment denominator')
        h_slope=moment_num/moment_den
        h_fine_bottom=physical%pressure_head(numnod)
        theta_fine_bottom=physical%water_content(numnod)
        face_distance_cm=0.5_real64*dz(numnod)
        write(*,'(*(g0))') 'ROMPURP_P5C_GW_INTERFACE|HISTORY=',trim(history_label(ih)), &
             '|STEP=',step,'|OBS_STEP=',step/OUTPUT_FACTOR, &
             '|THETA_PREV=',theta_prev,'|THETA_BOTTOM=',theta_bottom, &
             '|THETA_HALF1=',theta_half1,'|THETA_HALF2=',theta_half2, &
             '|H_SLOPE_BOTTOM=',h_slope,'|H_FINE_BOTTOM=',h_fine_bottom, &
             '|THETA_FINE_BOTTOM=',theta_fine_bottom,'|FACE_DISTANCE_CM=',face_distance_cm, &
             '|BOTTOM_FLUX=',bflux,'|BOTTOM_HEAD=',forcing%bottom_head
      end if"""
    text=one(text,old,new,"P5C interface diagnostic block")
    text=one(text,
      "write(*,'(A)') 'LAREGW1_ROMPURP_P5C_GW_REFERENCE_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_ROMPURP_P5C_GW_INTERFACE_GENERATED=TRUE'"+chr(10)+
      "          write(*,'(A)') 'LAREGW1_ROMPURP_P5C_GW_REFERENCE_GENERATED=TRUE'",
      "P5C marker")

    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(text)
    out={
      "schema":"swap5.rom-purpose.p5c.gw-interface-materialization.v1",
      "material":a.material,"temporal_factor":a.temporal_factor,
      "base_materialization":m,"diagnostic_route":"R512_T8",
      "diagnostic_fields":["THETA_PREV","THETA_BOTTOM","THETA_HALF1","THETA_HALF2",
                           "H_SLOPE_BOTTOM","H_FINE_BOTTOM","THETA_FINE_BOTTOM",
                           "FACE_DISTANCE_CM","BOTTOM_FLUX","BOTTOM_HEAD"],
      "solver_or_physics_changed":False,"numerical_policy_changed":False,
      "forcing_changed":False,"response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")

if __name__=="__main__": main()
