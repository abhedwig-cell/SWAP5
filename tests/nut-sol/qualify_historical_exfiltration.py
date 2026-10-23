"""Compile the authenticated historical surface block against the current operator."""
import argparse,base64,hashlib,io,json,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser()
 for opt in ['O0','O2']:ap.add_argument('--bundle-'+opt,type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(exist_ok=False)
 authority=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(authority.read_bytes())),mode='r:gz')as t:
  raw=t.extractfile('SWAP/solute.f90').read()
 original=raw.decode();start=original.index('            csurf = (nird*cirr + nraidt*cpre)*dtsolu + csurf')
 end=original.index('            end if',start)+len('            end if')
 fragment=original[start:end]
 assert 'cfluxt = 0.0d0'in fragment and 'qtop < -1.d-6'in fragment
 source='''program original_surface_comparison
 use mod_b111_pond_solute_exchange
 implicit none
 real(8)::csurf,nird,cirr,nraidt,cpre,dtsolu,qtop,ArMpSs,cpond,cfluxt,isqtop,pond,before
 real(8),parameter::flows(4)=[.039407159969323521d0,0d0,-1d-7,-.03d0]
 type(b111_pond_solute_result_t)::r
 integer::i,j
 do j=1,3
  do i=1,4
   before=.2d0*j;csurf=before;nird=.01d0;cirr=.4d0;nraidt=.1d0;cpre=.25d0
   dtsolu=.25d0;qtop=flows(i);ArMpSs=0d0;pond=.015d0;isqtop=0d0
'''+fragment+'''
   call evaluate_b111_pond_solute_exchange(before,nraidt,cpre,nird,cirr,qtop,ArMpSs,pond,dtsolu,r)
   if(r%status/=B111_POND_SOL_OK)error stop 'operator rejected original surface case'
   if(r%mass_after/=csurf.or.r%soil_transfer/=-cfluxt)error stop 'original surface drift'
   if(qtop>=-1d-6.and.r%soil_transfer/=0d0)error stop 'historical upward boundary transports solute'
  end do
 end do
 print *, 'HISTORICAL_SURFACE_12_EXACT_ZERO_UPWARD_CASES_PASS'
end program
'''
 (out/'original_surface.f90').write_text(source);events=[];builds={}
 for opt in ['O0','O2']:
  bundle=json.loads((getattr(a,'bundle_'+opt)/'bundle.json').read_text())
  build=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text());assert '-'+opt in build['flags']
  path='src/process/mod_b111_pond_solute_exchange.f90'
  assert sha((ROOT/path).read_bytes())==build['input_sha256'][path]
  objects=[e['command'][-1]for e in build['source_build']['events']if e['category']=='compile'and e['command'][-3]==str(ROOT/path)]
  assert len(objects)==1
  flags=[f for f in build['flags']if not f.startswith('-J')]+['-J'+str(out)]
  for cmd in [build['compiler_command']+flags+[out/'original_surface.f90',*objects,'-o',out/opt],[out/opt]]:
   start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=60)
   i=len(events)
   for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
   events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-start))
   assert r.returncode==0,(r.stdout,r.stderr)
  builds[opt]=dict(operator_sha256=sha((ROOT/path).read_bytes()),object_sha256=sha(Path(objects[0]).read_bytes()),flags=flags)
 report=dict(status='HISTORICAL_SURFACE_EXACT_ZERO_UPWARD_O0_O2_PASS',source_sha256=sha(raw),fragment_sha256=sha(fragment.encode()),
  authority_sha256=sha(authority.read_bytes()),driver_sha256=sha(source.encode()),builds=builds,events=events,cases_per_optimization=12,
  input_sha256={'tests/nut-sol/qualify_historical_exfiltration.py':sha(Path(__file__).read_bytes()),'src/process/mod_b111_pond_solute_exchange.f90':sha((ROOT/path).read_bytes())})
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
if __name__=='__main__':main()
