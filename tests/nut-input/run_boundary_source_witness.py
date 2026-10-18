"""Execute original six TTUTIL boundary reads and an explicit one-target B1 fix.

B0's unread seep destination is initialized only to expose the assignment defect;
this is not a claim about the undefined destination in a complete original run.
The source slice, correction and original TTUTIL providers are independently bound.
"""
from pathlib import Path
import base64,hashlib,io,json,os,subprocess,tarfile,time,zipfile
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_BOUNDARY_WITNESS_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
 management=t.extractfile('SWAP/management_soil.f90').read()
assert hashlib.sha256(management).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
original='\n'.join(management.decode().splitlines()[191:197])+'\n'
defect="call rdsdor ('cNO3N_seep',0.0d0,1000.0d0,cNO3N_lat)"
assert original.count(defect)==1
corrected=original.replace(defect,"call rdsdor ('cNO3N_seep',0.0d0,1000.0d0,cNO3N_seep)")
(OUT/'B0_boundary_reads.inc').write_text(original);(OUT/'B1_boundary_reads.inc').write_text(corrected)
raw=base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64').read_bytes())
assert hashlib.sha256(raw).hexdigest()=='ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193'
source=OUT/'source';zipfile.ZipFile(io.BytesIO(raw)).extractall(source);source=source/'TTUTIL'
fixture='cNH4N_top = .0005\ncNO3N_top = .0015\ncNH4N_lat = .003\ncNO3N_lat = .004\ncNH4N_seep = .001\ncNO3N_seep = .002\n'
events=[];results={}
def run(c,b,category):
 c=list(map(str,c));start=time.perf_counter();r=subprocess.run(c,cwd=b,input=b'',capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=c,category=category,returncode=r.returncode,seconds=time.perf_counter()-start,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();(b/'boundary.snm').write_text(fixture)
 providers=[source/'ttutilprefs.f90',source/'ttutil.f90']+sorted(p for p in source.glob('*.f90')if p.name not in ['ttutilprefs.f90','ttutil.f90'])+sorted(source.glob('*.for'))
 objects=[]
 flags=['-'+opt,'-std=legacy','-fallow-argument-mismatch','-ffixed-line-length-none','-ffree-line-length-none','-I'+str(source),'-I'+str(b),'-J'+str(b)]
 for i,p in enumerate(providers):
  o=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',o],b,'compile');objects.append(o)
 results[opt]={}
 for name,reads in [('B0',original),('B1',corrected)]:
  code='''program witness
 implicit none
 real(8)::cNH4N_top,cNH4N_lat,cNH4N_seep,cNO3N_top,cNO3N_lat,cNO3N_seep
 cNO3N_seep=0d0
 call rdinit(20,0,'boundary.snm')
'''+reads+'''
 if(abs(cNH4N_top-.0005d0)>1d-14.or.abs(cNO3N_top-.0015d0)>1d-14)error stop 1
 if(abs(cNH4N_lat-.003d0)>1d-14.or.abs(cNH4N_seep-.001d0)>1d-14)error stop 2
'''+(''' if(abs(cNO3N_lat-.002d0)>1d-14.or.cNO3N_seep/=0d0)error stop 3
 print '(A)','B0_SEEP_OVERWRITES_LATERAL_DESTINATION=CONFIRMED'
'''if name=='B0'else''' if(abs(cNO3N_lat-.004d0)>1d-14.or.abs(cNO3N_seep-.002d0)>1d-14)error stop 4
 print '(A)','B1_DISTINCT_TOP_LATERAL_BOTTOM_CONCENTRATIONS=PASS'
''')+''' close(20)
 print *,cNH4N_top,cNO3N_top,cNH4N_lat,cNO3N_lat,cNH4N_seep,cNO3N_seep
end program
'''
  p=b/(name+'.f90');p.write_text(code);exe=b/name
  run(['gfortran',*flags,p,*objects,'-o',exe],b,'link')
  results[opt][name]=run([exe],b,'native')
assert results['O0']==results['O2']
r=dict(status='ORIGINAL_BOUNDARY_B0_DEFECT_B1_SINGLE_TARGET_FIX_O0_O2_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),management_sha256=hashlib.sha256(management).hexdigest(),ttutil_zip_sha256=hashlib.sha256(raw).hexdigest(),slice_lines=[192,197],B0_slice_sha256=sha(OUT/'B0_boundary_reads.inc'),B1_slice_sha256=sha(OUT/'B1_boundary_reads.inc'),runner_sha256=sha(Path(__file__)),source_sha256={p.name:sha(p)for p in source.iterdir()if p.is_file()},fixture=fixture,results=results,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
