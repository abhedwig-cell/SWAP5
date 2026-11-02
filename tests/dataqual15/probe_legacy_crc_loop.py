"""Isolate the legacy CRC loop/toolchain defect; never execute model physics."""
import argparse,hashlib,json,os,re,shutil,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--input',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);p.add_argument('--timeout',type=float,default=3)
    a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    compiler=shutil.which('gfortran');assert compiler
    source=ROOT/'src/adapter/mod_age_joint_restart_file.f90'
    routine=re.search(r'  function crc32\(bytes\).*?  end function',source.read_text(),re.S).group()
    driver=out/'crc.f90';driver.write_text('''program probe
use iso_fortran_env,only:int8,int32
implicit none
integer(int8),allocatable::bytes(:)
integer::u,n
character(2048)::path
call get_command_argument(1,path)
inquire(file=trim(path),size=n)
allocate(bytes(n))
open(newunit=u,file=trim(path),access='stream',form='unformatted',status='old')
read(u)bytes
close(u)
write(*,'(z8.8)')crc32(bytes)
contains
'''+routine+'\nend program\n')
    data=out/'input.bin';data.write_bytes(a.input.read_bytes());events=[]
    for name,flags in [('O0',['-O0','-fcheck=all']),('O2',['-O2','-fcheck=all']),
                       ('novector',['-O2','-fcheck=all','-fno-tree-vectorize']),
                       ('noloop',['-O2','-fcheck=all','-fno-tree-loop-optimize'])]:
        exe=out/(name+('.exe'if os.name=='nt'else''))
        command=[compiler,*flags,str(driver),'-o',str(exe)]
        cp=subprocess.run(command,capture_output=True);(out/(name+'.compile.stderr')).write_bytes(cp.stderr)
        assert cp.returncode==0,cp.stderr
        start=time.monotonic()
        try:
            cp=subprocess.run([str(exe),str(data)],capture_output=True,timeout=a.timeout)
            assert cp.returncode==0 and int(cp.stdout.strip(),16)==zlib.crc32(data.read_bytes())
            event=dict(status='CRC_EXACT',returncode=cp.returncode)
        except subprocess.TimeoutExpired as error:
            cp=error;event=dict(status='TIMEOUT_NOT_PASS',timeout_seconds=a.timeout)
        (out/(name+'.stdout')).write_bytes(cp.stdout or b'');(out/(name+'.stderr')).write_bytes(cp.stderr or b'')
        events.append(dict(name=name,flags=flags,compile_command=command,seconds=time.monotonic()-start,**event))
    result=dict(status='DIAGNOSTIC_NOT_MODEL_QUALIFICATION',compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
                input_sha256=hashlib.sha256(data.read_bytes()).hexdigest(),routine_sha256=hashlib.sha256(routine.encode()).hexdigest(),
                source=source.relative_to(ROOT).as_posix(),events=events)
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
