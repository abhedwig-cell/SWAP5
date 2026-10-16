#!/usr/bin/env python3
"""Small real reproductive/death production contract and immutable literal oracle."""
import base64,hashlib,io,json,os,pathlib,shlex,subprocess,tarfile,time
ROOT=pathlib.Path(__file__).resolve().parents[2];OUT=pathlib.Path(os.environ['REPRODUCTIVE_PROCESS_RESULT_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=False)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[]
archive=ROOT/'integration/audits/evidence/MC_NUT01_B111_NFIX_COMPONENT_20261016.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as a:raw=a.extractfile('literal/wofostnut.f90').read()
assert hashlib.sha256(raw).hexdigest()=='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2'
lines=raw.decode('latin1').splitlines()
pre='''module literal_reproductive
 use iso_fortran_env,only:real64
 use MOD_wofost81_nitrogen,only:WOFOST81_n_param,WOFOST81_n_state
 implicit none
contains
 subroutine literal(p,policy,n,dvs,nmaxlv,m,dead,reltr,supply,after,loss,trans,uptake,requests,unclipped)
 type(WOFOST81_n_param),intent(in)::p
 type(WOFOST81_n_state),intent(in)::n
 real(real64),intent(in)::policy(4),dvs,nmaxlv,m(4),dead(3),reltr,supply
 real(real64),intent(out)::after(8),loss(3),trans(3),uptake(3),requests(6),unclipped(3)
 real(real64)::wlv,wst,wrt,wso,anlv,anst,anrt,anso,rnflv,rnfst,rnfrt,nmaxst,nmaxrt,nmaxso
 real(real64)::drlv,drst,drrt,dvsnlt,dvsnt,nfixf,fntrt,tcnt,delt,nsupplysoil
 real(real64)::ndeml,ndems,ndemr,ndemso,ndemto,nlimit,ndemandsoil,ndemandbiofix,nuptr,nfixtr
 real(real64)::atnst,atnlv,atnrt,atn,nsupso,rnso,rntlv,rntst,rntrt,rnulv,rnust,rnurt
 real(real64)::rnldrt,rnldst,rnldlv,rnlv,rnst,rnrt,nuptt,nfixtt,nlossl,nlossr,nlosss
 wlv=m(1);wst=m(2);wrt=m(3);wso=m(4)
 anlv=n%namountlv;anst=n%namountst;anrt=n%namountrt;anso=n%namountso
 rnflv=p%nresidlv;rnfst=p%nresidst;rnfrt=p%nresidrt
 nmaxst=nmaxlv*p%nmaxst_fr;nmaxrt=nmaxlv*p%nmaxrt_fr;nmaxso=p%nmaxso
 drlv=dead(1);drst=dead(2);drrt=dead(3)
 dvsnlt=policy(1);dvsnt=policy(2);nfixf=policy(3);fntrt=policy(4)
 tcnt=p%tcnt;delt=1d0;nsupplysoil=supply
 nuptt=n%nuptake_total;nfixtt=n%nfix_total;nlossl=n%nlosses_total;nlossr=0d0;nlosss=0d0
'''
# Literal blocks, including the original max(0,x) updates, are never rewritten.
oracle=pre+'\n'.join(lines[353:370])+'\n'+'\n'.join(lines[196:246])+'''\n unclipped=[anlv+rnlv*delt,anst+rnst*delt,anrt+rnrt*delt]\n'''+ '\n'.join(lines[246:255])+'''
 after=[anlv,anst,anrt,anso,nuptt,nfixtt,nlossl+nlossr+nlosss,n%initial_total]
 loss=[rnldlv,rnldst,rnldrt];trans=[rntlv,rntst,rntrt];uptake=[rnulv,rnust,rnurt]
 requests=[ndemto,ndemso,ndemandsoil,ndemandbiofix,atn,rnso]
 end subroutine
end module
'''
(OUT/'literal.f90').write_text(oracle);inputs={}
for opt in ('O0','O2'):
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 sources=[ROOT/'src/crop/mod_wofost81_nitrogen.f90',ROOT/'src/crop/mod_b111_reproductive_n_process.f90',OUT/'literal.f90',ROOT/'tests/nut-crop/test_reproductive_process.f90'];objects=[]
 cmds=[]
 for i,p in enumerate(sources):
  obj=b/f'{i}.o';objects.append(obj);cmds.append(('compile',FC+flags+['-c',p,'-o',obj]))
  if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
 cmds += [('link',FC+flags+objects+['-o',b/'test']),('native',[b/'test'])]
 for category,args in cmds:
  args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=b,capture_output=True);i=len(events)
  (OUT/f'{i}.stdout').write_bytes(p.stdout);(OUT/f'{i}.stderr').write_bytes(p.stderr);events.append(dict(category=category,command=args,returncode=p.returncode,seconds=time.perf_counter()-t,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
  if p.returncode:print(p.stdout.decode(),p.stderr.decode());p.check_returncode()
 assert b'B111_REPRODUCTIVE_LITERAL_CORPUS_GUARDS=PASS'in p.stdout
 if opt=='O0':first=p.stdout
 else:assert first==p.stdout
inputs[str(pathlib.Path(__file__).relative_to(ROOT))]=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
(OUT/'result.json').write_text(json.dumps(dict(status='PROCESS_PASS_NOT_RUNTIME_ADMISSION',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,authority_sha256=hashlib.sha256(raw).hexdigest(),literal_lines=[[354,370],[197,255]],oracle_sha256=hashlib.sha256(oracle.encode()).hexdigest(),compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],stdout=first.decode(),cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native']}),indent=2)+'\n')
print('PROCESS_O0_O2_PASS_NOT_RUNTIME_ADMISSION')
