from pathlib import Path
import hashlib,json,subprocess,shutil,sys,os,time,difflib
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent;B=R.parent/'swap431-macro-b1-reject64';P=R.parent/'swap431-macro-b1-follow67'
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e');W=ROOT/'successor68-data';OLD=ROOT/'follow67-data/evidence/data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def save(p,q):p.write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
def generate():
    old=(B/'jac63_update.f90').read_text();terms,solve=old.split('subroutine jac63_solve',1)
    ext=terms.replace('jac63_terms','jac68_terms').replace('t1900/=35797.290431125148d0','t1900/=35797.290441125151d0')
    assert ext.replace('jac68_terms','jac63_terms').replace('t1900/=35797.290441125151d0','t1900/=35797.290431125148d0')==terms
    solve='subroutine jac63_solve'+solve
    solve=solve.replace('implicit none','use variables,only:t1900\nimplicit none',1)
    solve=solve.replace('call jac63_terms(n,uu,vv,meta,handled)', '''real(8)::u68(macp,2),v68(macp,2),m68(24)
logical::e68
logical,save::opened68=.false.,done68(2)=.false.
integer,save::unit68
integer::st68,b68
character(8)::enabled68,probe68
call jac63_terms(n,uu,vv,meta,handled)
if(t1900==35797.290441125151d0) then
 call jac68_terms(n,u68,v68,m68,e68)
 call get_environment_variable('SUCCESSOR68_ENABLE',enabled68,status=st68)
 if(st68/=0) enabled68='0'
 if(trim(enabled68)=='1') then
  uu=u68;vv=v68;meta=m68;handled=e68
 end if
 if(.not.opened68) then
  open(newunit=unit68,file='successor68_guard.txt',status='replace');opened68=.true.
 end if
 write(unit68,*) attempts,iter_index,m68,merge(1,0,e68),merge(1,0,handled)
 flush(unit68)
 call get_environment_variable('SUCCESSOR68_PROBE',probe68,status=st68)
 if(st68/=0) probe68='0'
 if(e68.and.handled.and.trim(probe68)=='1') then
  b68=nint(m68(3))
  if(b68<1.or.b68>2) error stop 'SUCCESSOR68 invalid branch'
  if(.not.done68(b68)) then
   done68(b68)=.true.
   call potential68_probe(b68)
  end if
 end if
end if''',1)
    s=terms+solve+'\n'+ext
    (R/'jac68_update.f90').write_text(s);(R/'CORRECTION.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='COMBINED63/jac63_update.f90',tofile='SUCCESSOR68/jac68_update.f90')))
    old=(R.parent/'swap431-macro-b1-potential61/potential61_probe.f90').read_text();s=old.replace('potential61_probe()','potential68_probe(branch68)',1)
    s=s.replace('integer::u,pu,ru', 'integer,intent(in)::branch68\ninteger::u,pu,ru',1)
    start=s.index("if(attempts/=2.or.");end=s.index('oldbusy=',start)
    s=s[:start]+'''if(branch68<1.or.branch68>2) error stop 'POTENTIAL68 branch'
write(base,'(a,i0,a)') 'potential68_b',branch68,'_base.bin'
write(rest,'(a,i0,a)') 'potential68_b',branch68,'_restored.bin'
write(cache,'(a,i0,a)') 'potential68_b',branch68,'_cache.bin'
write(crest,'(a,i0,a)') 'potential68_b',branch68,'_cache_restored.bin'
write(points,'(a,i0,a)') 'potential68_b',branch68,'_points.txt'
write(receipt,'(a,i0,a)') 'potential68_b',branch68,'_restore.txt'
write(limits,'(a,i0,a)') 'potential68_b',branch68,'_limits.txt'
'''+s[end:]
    s=s.replace('call record(0,0d0)','call MACRORATE(1)\ncall record(0,0d0)',1)
    s=s.replace('call restore();pid=pid+1;call record(0,0d0)','call restore();pid=pid+1;call MACRORATE(1);call record(0,0d0)\ncall restore()',1)
    (R/'potential68_probe.f90').write_text(s);(R/'OBSERVER.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='POTENTIAL61/potential61_probe.f90',tofile='SUCCESSOR68/potential68_probe.f90')))
def build(opt):
    out=ROOT/('successor68-'+opt);src=ROOT/('follow67-'+opt);ident=json.loads((P/(opt+'_IDENTITY.json')).read_text())
    assert sha(src/'follow67.exe')==ident['exe_sha256']
    if not (out/'obj').exists():
        shutil.copytree(src/'obj',out/'obj');shutil.copy2(src/'libttutil.a',out/'libttutil.a')
    obj=out/'obj'
    for n,h in ident['objects'].items():
        if n!='jac63.o' or not (R/(opt+'_RESTORED.json')).exists():assert sha(obj/n)==h
    if not (R/(opt+'_RESTORED.json')).exists():save(R/(opt+'_RESTORED.json'),dict(objects={p.name:sha(p) for p in obj.iterdir() if p.is_file()},parent_exe_sha256=ident['exe_sha256']))
    commands=[]
    for source,name in [('potential68_probe.f90','potential68.o'),('jac68_update.f90','jac63.o')]:
        commands.append(['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/source),'-o',str(obj/name)])
    linkobjects=sorted(set(obj.glob('*.o'))|{obj/'potential68.o'})
    commands.append(['gfortran','-o',str(out/'successor68.exe'),*map(str,linkobjects),str(out/'libttutil.a')])
    logs=[]
    for cmd in commands:
        t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
    save(R/(opt+'_IDENTITY.json'),dict(exe_sha256=sha(out/'successor68.exe'),sources={p.name:sha(p) for p in R.glob('*.f90')},compiler=subprocess.check_output(['gfortran','--version'],text=True),objects={p.name:sha(p) for p in obj.glob('*.o')}))
def run(opt,mode):
    assert (opt,mode) in [('O0','QUAL'),('O0','BARE'),('O0','FD'),('O2','BARE'),('O2','FD'),('O0','CONT'),('O2','CONT')]
    label=opt+'_'+mode;c=W/'runs'/label;out=W/'evidence/data'/label
    assert not c.exists() and not out.exists();c.mkdir(parents=True);out.mkdir(parents=True)
    base=OLD/(opt+('_CONT' if mode=='CONT' else '_RESTART'));inp=json.loads((base/'INPUT.json').read_text())
    manifest=inp['baseline_case']['original_case_manifest']
    for x in manifest:
        p=base/x['path'];assert sha(p)==x['sha256'] or x['path']=='swap.swp'
        dst=c/x['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    for n in ['swap.swp','own.end','calibration_base.bin']:shutil.copy2(base/n,c/n)
    if mode!='CONT':assert sha(c/'own.end')=='d5ee169f99cebe1a8dd849b39bfe51d06bdbcf5f226e127d2d70246807a373d7'
    env=os.environ.copy();env.update(inp['environment']);env['SUCCESSOR68_ENABLE']='0' if mode=='QUAL' else '1';env['SUCCESSOR68_PROBE']='1' if mode=='FD' else '0'
    env['PYTHONDONTWRITEBYTECODE']='1'
    exe=ROOT/('successor68-'+opt)/'successor68.exe';identity=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert sha(exe)==identity['exe_sha256']
    save(out/'INPUT.json',dict(identity=identity,baseline=inp,environment={k:env[k] for k in [*inp['environment'],'SUCCESSOR68_ENABLE','SUCCESSOR68_PROBE']},own_end_sha256=sha(c/'own.end'),mode=mode))
    t=time.perf_counter()
    try:
        p=subprocess.run([str(exe),'./swap.swp'],cwd=c,env=env,capture_output=True,text=True,timeout=20);q=dict(returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired as e:q=dict(censored=True,seconds=time.perf_counter()-t,stdout=str(e.stdout),stderr=str(e.stderr))
    save(out/'RUN.json',q)
    for p in c.rglob('*'):
        if p.is_file():
            dst=out/p.relative_to(c);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
    print(label,json.dumps(q));assert not q['censored'] and q['returncode']==0
if __name__=='__main__':
    if sys.argv[1]=='prepare':generate();build('O0');build('O2')
    else:run(*sys.argv[1:3])
