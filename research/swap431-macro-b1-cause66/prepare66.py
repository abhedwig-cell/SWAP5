from pathlib import Path
import hashlib,json,subprocess,io,zipfile,shutil,time,sys,difflib
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent;OLD=R.parent/'swap431-macro-b1-reject64'
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e')
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(n,q):(R/n).write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def restore(opt):
    raw=subprocess.check_output(['git','show','95a61203:research/swap431-macro-b1-reject64/REJECT64_EVIDENCE.zip'],cwd=R)
    assert hashlib.sha256(raw).hexdigest()=='f8931da9a481e3f29b0918282bb761ca9a4701c762f92a2c6cfd50243dccafb3'
    out=ROOT/('cause66-'+opt);prefix='native/'+opt+'/'
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        for x in json.loads(z.read('manifest.json')):
            if x['path'].startswith(prefix):
                p=out/x['path'][len(prefix):];p.parent.mkdir(parents=True,exist_ok=True)
                p.write_bytes(z.read(x['path']));assert sha(p)==x['sha256']
    assert sha(out/'native09.exe')==json.loads((OLD/(opt+'_IDENTITY.json')).read_text())['exe_sha256']
    save(opt+'_RESTORED.json',dict(exe_sha256=sha(out/'native09.exe'),object_hashes={p.name:sha(p) for p in (out/'obj').iterdir() if p.is_file()}))
def generate():
    old=(OLD/'head_diag.f90').read_text()
    s=old.replace('   diag_active=.false.','   call cause66_boundary(0)\n   diag_active=.false.',1)
    key='   call vector_F(1, hgrad)'
    assert s.count(key)==1
    s=s.replace(key,key+"\n   call cause66_boundary(1)\n   block\n    integer::u66\n    open(newunit=u66,file='cause66_F0.txt',position='append',status='unknown')\n    write(u66,*) attempts,NN,t1900,dt\n    write(u66,*) F(1:NN)\n    close(u66)\n   end block",1)
    s+='''
subroutine cause66_boundary(stage)
 use variables,only:t1900,dt,deepgw,qbot,hbot,gwlinp,rimlay,swbotb,swbotb3impl,swbotb3resvert,sw3,sw4,haqtab,h,kmean
 use MOD_arrays,only:mabbc
 use MOD_grid,only:numnod,z,disnod
 use DIAG19,only:attempts
 implicit none
 integer,intent(in)::stage
 integer::u,st
 character(24)::mode
 real(8)::afgen,before,endpoint
 before=deepgw;endpoint=t1900+dt
 call get_environment_variable('CAUSE66_ENDPOINT',mode,status=st)
 if(st/=0) mode='NONE'
 if(abs(t1900-35797.290431125148d0)>1d-10.or.swbotb/=3.or.swbotb3impl/=1.or.sw3/=2.or.sw4/=0) &
    error stop 'CAUSE66 outside preregistered boundary context'
 if(stage==0) then
  select case(trim(mode))
  case('NONE')
  case('SMALL')
   if(attempts>1) deepgw=afgen(haqtab,mabbc*2,t1900+dt)
  case('LARGE')
   if(attempts==1.and.dt==1d-5) then
    endpoint=t1900+2.0951312035156963d-5
    deepgw=afgen(haqtab,mabbc*2,endpoint)
   end if
  case default
   error stop 'CAUSE66 unselected intervention'
  end select
 end if
 open(newunit=u,file='cause66_boundary.txt',position='append',status='unknown')
 write(u,*) attempts,stage,t1900,dt,endpoint,before,deepgw,qbot,hbot,gwlinp,rimlay, &
   swbotb,swbotb3impl,swbotb3resvert,sw3,sw4,h(numnod),z(numnod),disnod(numnod+1),kmean(numnod+1)
 close(u)
end subroutine cause66_boundary
'''
    (R/'head_observer66.f90').write_text(s,encoding='utf-8')
    (R/'OBSERVER.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='REJECT64/head_diag.f90',tofile='CAUSE66/head_observer66.f90')),encoding='utf-8')
def build(opt,stage):
    out=ROOT/('cause66-'+opt);obj=out/'obj'
    src=R/('head_observer66.f90' if stage=='OBS' else 'swap_repair66.f90')
    dest='headcalc.o' if stage=='OBS' else 'swap.o'
    commands=[['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(src),'-o',str(obj/dest)],['gfortran','-o',str(out/(stage+'.exe')),*map(str,sorted(obj.glob('*.o'))),str(out/'libttutil.a')]]
    logs=[]
    for cmd in commands:
        t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60)
        logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(opt+'_'+stage+'_BUILD.json',logs)
        assert p.returncode==0,p.stderr
    save(opt+'_'+stage+'_IDENTITY.json',dict(exe_sha256=sha(out/(stage+'.exe')),source_sha256=sha(src),compiler=subprocess.check_output(['gfortran','--version'],text=True),objects={p.name:sha(p) for p in obj.glob('*.o')}))
if __name__=='__main__':
    if sys.argv[1]=='prepare':
        generate();restore('O0');restore('O2')
    else:build(*sys.argv[1:3])
