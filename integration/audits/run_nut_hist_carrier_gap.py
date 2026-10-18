"""Reproduce the gross/net counterexample with original transport and real owner.

Diagnostic coverage, never an admission gate or a claim of full legacy equality.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_CARRIER_GAP_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda x:hashlib.sha256(x).hexdigest()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes()))) as t:
 raw=t.extractfile('SWAP/wofost_soil_watern.f90').read()
 management=t.extractfile('SWAP/management_soil.f90').read()
assert sha(raw)=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
assert sha(management)=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
lines=management.decode('latin1').splitlines()
assert 'Wflux_inTop = help' in lines[401] and 'SoilEvap' in lines[400]
(OUT/'management_390_407.txt').write_text('\n'.join(f'{i+1}: {lines[i]}' for i in range(389,407))+'\n')
providers=[ROOT/'src/process'/f'{n}.f90' for n in ['mod_soil_n_pool_state','mod_b111_soil_n_storage_conversion','mod_b111_soil_n_transport','mod_b111_soil_n_mineral_owner']]
driver=ROOT/'integration/audits/test_nut_hist_carrier_gap.f90'
events=[];outputs={}
def run(args,b,category):
 args=list(map(str,args));start=time.perf_counter();p=subprocess.run(args,cwd=b,capture_output=True)
 i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:03d}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=args,category=category,seconds=time.perf_counter()-start,returncode=p.returncode))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();original=b/'original.f90';original.write_bytes(raw)
 fixture=b/'fixture.f90';fixture.write_text('''module MOD_texture_orgmat
 use iso_fortran_env,only:real64
 real(real64)::bdens(1)
end module
subroutine swap_error(a,b)
 character(*),intent(in)::a,b
 print *,a,b
 error stop 1
end subroutine
''')
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 objs=[]
 for i,p in enumerate([fixture,original]+providers+[driver]):
  o=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',o],b,'compile');objs.append(o)
 exe=b/'witness';run(['gfortran',*flags,*objs,'-o',exe],b,'link')
 outputs[opt]=run([exe],b,'native')
 assert 'HIST_GROSS_NET_INFORMATION_LOSS_WITNESS=PASS' in outputs[opt]
assert outputs['O0']==outputs['O2']
r=dict(status='DIAGNOSTIC_WITNESS_PASS_FULL_HIST_NOT_QUALIFIED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),compiler=run(['gfortran','--version'],OUT,'compiler').splitlines()[0],input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in providers+[driver,Path(__file__),archive]},original_transport_sha256=sha(raw),management_sha256=sha(management),outputs=outputs,cost_seconds={k:sum(e['seconds'] for e in events if e['category']==k) for k in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
