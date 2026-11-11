"""Record accepted Grassgrowth root inputs on day 188 in both model routes."""
import argparse
from hashlib import sha256
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
INPUTS = ("swap.swp","grass.crp","260.met","swap.bbc","swap.dra")
NATIVE = """
     if(day_index==188)then
      write(*,'(a,*(1x,es25.17e3))') 'NATIVE_ROOT',q%t0,q%t1,q%root_potential_cm_day, &
       sum(q%root_sink),q%root_drought_reduction_cm_day,q%root_oxygen_reduction_cm_day, &
       root_state%actual_root_depth_cm,q%deepest_root_oxygen_factor
      write(*,'(a,*(1x,es25.17e3))') 'NATIVE_NODES',q%water_start, &
       q%thermal%temperature_start_c,q%root_sink
      if(allocated(q%root_pressure_head_start)) &
       write(*,'(a,*(1x,es25.17e3))') 'NATIVE_HEAD',q%root_pressure_head_start
      if(allocated(q%potential_root_sink)) &
       write(*,'(a,*(1x,es25.17e3))') 'NATIVE_POT',q%potential_root_sink
     end if
"""
LEGACY_USE = """
use variables,only: obs_clock=>t1900,obs_h=>h,obs_theta=>theta,obs_qrot=>qrot
use MOD_meteo,only:obs_ptra=>ptra
use MOD_re_global,only:obs_actual=>qrosum,obs_dry=>qreddrysum,obs_oxy=>qredwetsum, &
 obs_pot=>qpotrot,obs_wet=>alpwet,obs_deep=>alpwetnoddrz
use plant_interface,only:obs_rd=>rd,obs_nodes=>noddrz
"""
LEGACY_BEFORE = """
      if(obs_clock>=29407d0.and.obs_clock<29408d0)then
         obs_start_h=obs_h(1:113);obs_start_theta=obs_theta(1:113);obs_start_temp=tsoil(1:113)
      end if
"""
LEGACY_AFTER = """
      if(obs_clock>=29407d0.and.obs_clock<29408d0)then
         write(*,'(a,*(1x,es25.17e3))') 'LEGACY_ROOT',obs_clock,dt,obs_ptra,obs_actual,obs_dry,obs_oxy,obs_rd,obs_deep
         write(*,'(a,*(1x,es25.17e3))') 'LEGACY_NODES',obs_start_h,obs_start_theta,obs_start_temp, &
            obs_pot(1:113),obs_qrot(1:113)
         if(allocated(obs_wet))write(*,'(a,*(1x,es25.17e3))') 'LEGACY_WET',obs_wet(1:obs_nodes)
         if(abs(obs_clock+dt-29408d0)<1d-8)stop 73
      end if
"""


def sha(path):
    return sha256(path.read_bytes()).hexdigest()


def inject(text, anchor, insertion, before=False):
    assert text.count(anchor) == 1, anchor
    return text.replace(anchor, insertion+anchor if before else anchor+insertion)


def link(out, source, flags, objects, replaced, archive):
    exe=out/"observed.exe"
    compile_cmd=["gfortran",*flags,"-c",source.name,"-o","observed.o"]
    subprocess.run(compile_cmd,cwd=out,check=True)
    link_cmd=["gfortran","-fopenmp","-o",str(exe),
              *["observed.o" if p==replaced else str(p) for p in objects],str(archive)]
    subprocess.run(link_cmd,cwd=out,check=True)
    return exe, [compile_cmd,link_cmd]


def execute(exe, out, args, code):
    with (out/"stdout").open("wb") as log:
        result=subprocess.run([exe,*args],cwd=out,stdin=subprocess.DEVNULL,stdout=log,
                              stderr=subprocess.STDOUT,timeout=120)
    assert result.returncode==code, result.returncode


def legacy(ref,out):
    out.mkdir()
    original=ref/"swap-selected/swap.f90"
    text=original.read_text(encoding="cp1252")
    pos=text.index("subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap) ")
    prefix,body=text[:pos],text[pos:]
    body=inject(body,"use swap_exchange\n",LEGACY_USE)
    body=inject(body,"logical :: flError\n","real(8)::obs_start_h(113),obs_start_theta(113),obs_start_temp(113)\n")
    body=inject(body,"      if (swcrop == 1) call RootExtraction(2)",LEGACY_BEFORE,before=True)
    body=inject(body,"      call integral(3)",LEGACY_AFTER)
    source=out/"swap.f90";source.write_text(prefix+body,encoding="cp1252")
    obj=ref/"swap-obj";tt=ref/"ttutil-obj"
    exe,commands=link(out,source,["-O2","-cpp","-Dlinux","-finit-local-zero",
       "-ffree-line-length-none","-fallow-argument-mismatch","-I",str(obj),"-I",str(tt)],
       sorted(obj.glob("*.o")),obj/"swap.o",tt/"libttutil.a")
    for name in INPUTS:
        shutil.copyfile(ROOT/"reference/swap-4.3.1/projects/2.grassgrowth"/name,out/name)
    execute(exe,out,["./swap.swp"],73)
    return {"original_source_sha256":sha(original),"observer_source_sha256":sha(source),
            "exe_sha256":sha(exe),"inputs_sha256":{name:sha(out/name) for name in INPUTS},
            "commands":commands}


def native(bundle,control,archive,out):
    out.mkdir()
    meta=json.loads((bundle/"BUILD.json").read_text())
    assert sha(bundle/meta["executable"])==meta["executable_sha256"]
    assert sha(archive)==meta["original_input_archive_sha256"]
    assert all(sha(Path(p))==h for p,h in meta["source_sha256"].items())
    assert all(sha(Path(p))==h for p,h in meta["object_sha256"].items())
    sources=list(meta["source_sha256"])
    objects=list(map(Path,meta["object_sha256"]))
    driver=next(i for i,p in enumerate(sources) if Path(p).name=="initial_interval.f90")
    original=Path(sources[driver])
    source=out/original.name
    source.write_text(inject(original.read_text(),"     day_potential=day_potential+q%root_potential_cm_day*step_dt",NATIVE,before=True))
    flags=[f for f in meta["flags"] if not f.startswith(("-I","-J"))]+["-I",str(bundle),"-J",str(out)]
    exe,commands=link(out,source,flags,objects,objects[driver],archive)
    names=(*meta["original_inputs_sha256"],"application.binding","checkpoint-187.bin")
    for name in names:
        shutil.copyfile(control/name,out/name)
    assert all(sha(out/n)==h for n,h in meta["original_inputs_sha256"].items())
    assert sha(out/"application.binding")==meta["application_binding_sha256"]
    execute(exe,out,["188","retain-step","100000","checkpoint-187.bin"],0)
    assert (out/"checkpoint.bin").read_bytes()==(control/"checkpoint-188.bin").read_bytes()
    return {"original_source_sha256":sha(original),"observer_source_sha256":sha(source),
            "exe_sha256":sha(exe),"predecessor_exe_sha256":meta["executable_sha256"],
            "input_sha256":meta["original_inputs_sha256"],"commands":commands,
            "original_binding_preserved_for_observer":True,
            "origin_sha256":sha(out/"checkpoint-187.bin"),
            "terminal_sha256":sha(out/"checkpoint.bin")}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ("reference","bundle","control","archive","output"):
        p.add_argument("--"+key,type=Path,required=True)
    a=p.parse_args()
    out=a.output.resolve();out.mkdir()
    result={"legacy":legacy(a.reference.resolve()/"build",out/"legacy"),
            "native":native(a.bundle.resolve(),a.control.resolve(),a.archive.resolve(),out/"native")}
    for key in result:
        result[key]["stdout_sha256"]=sha(out/key/"stdout")
    (out/"RESULT.json").write_text(json.dumps(result,indent=2)+"\n")


if __name__=="__main__":
    main()
