"""Original SWMACRO1/SWSOLU0 geometry and retained rounded source output."""
import argparse,csv,decimal,gzip,hashlib,io,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda b:hashlib.sha256(b).hexdigest();p=argparse.ArgumentParser();p.add_argument('--fc',required=True);p.add_argument('--input-build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();events=[];S=ROOT/'tests/qualification/ppa-wu05-migmac10-canonical-20261006';inputs={};results={};geometries=[]
for name in ['swap.swp','swap.bbc']:
 p=S/('b111-'+name+'.gz');(out/name).write_bytes(gzip.decompress(p.read_bytes()));inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
def run(cmd,stage,label,ok=True):
 start=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=stage,capture_output=True,timeout=60)
 for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=cp.returncode,expected_success=ok,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert(cp.returncode==0)==ok,(label,cp.stdout.decode()[-1000:],cp.stderr.decode()[-2500:]);return cp
providers=[ROOT/p for p in ['src/runtime/mod_macropore_continuation_state.f90','src/process/macropore/mod_ppa_wu05a5_top_partition.f90','src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90','app/solute_column/read_swp_macro_geometry.f90','tests/nut-sol/test_native_macro_geometry.f90']]
for opt in ['O0','O2']:
 build=out/opt;run(['python','-B',ROOT/'tools/solute/build_macro_geometry_reader.py','--fc',a.fc,'--input-build',a.input_build,'--optimization',opt,'--output',build],out,opt+'-build');b=json.loads((build/'build-complete.json').read_bytes());inputs.update(b['input_sha256']);exe=build/'swap5_read_macro_geometry';g=out/(opt+'.nml');run([exe,out/'swap.swp',out/'swap.bbc',g],out,opt+'-native');geometries.append(g.read_bytes());text=g.read_text();v={k:[float(x)for x in x.split(',')if x.strip()]for k,x in re.findall(r'^\s*(\w+)=(.*)$',text,re.M)};assert v['nodes']==[112.]and v['domains']==[5.]and v['top_node']==[1.]
 old=gzip.decompress((S/'b111-macrogeom.csv.gz').read_bytes()).decode().replace('\0','');oldrows=[r for r in list(csv.reader(io.StringIO('\n'.join(old.splitlines()[5:]))))[1:]if r and r[0].strip()];assert len(oldrows)==112
 for i,row in enumerate(oldrows):
  expected=list(map(decimal.Decimal,[x.strip()for x in row[1:]]));observed=[sum(v['dz'][:i+1]),*v['fractions'][i*5:(i+1)*5],v['static_volume'][i],v['static_volume'][i]*v['fractions'][i*5],v['static_volume'][i]*sum(v['fractions'][i*5+1:(i+1)*5])];assert len(expected)==len(observed)==9
  for x,y in zip(expected,observed):assert abs(float(x)-y)<=.51*10.**x.as_tuple().exponent+1e-14,(i,x,y)
 c=out/(opt+'-consumer');c.mkdir();cexe=c/'consumer';flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(c),'-I'+str(c)];run([a.fc,*flags,*providers,'-o',cexe],c,opt+'-consumer-link');cp=run([cexe,g],c,opt+'-consumer-native');results[opt]=dict(geometry_sha256=sha(g.read_bytes()),consumer_stdout_sha256=sha(cp.stdout),retained_rounded_rows=112)
 original=(out/'swap.swp').read_bytes()
 for label,modified in [('macro-off',original.replace(b'SWMACRO = 1',b'SWMACRO = 0')),('solute-on',original.replace(b'SWSOLU = 0',b'SWSOLU = 1')),('bad-diameter',re.sub(rb'(?im)^(\s*DIPOMI\s*=\s*)[\d.]+',rb'\g<1>0.',original))]:
  assert modified!=original;p=out/(opt+'-'+label+'.swp');p.write_bytes(modified);target=out/(opt+'-'+label+'.nml');run([exe,p,out/'swap.bbc',target],out,opt+'-'+label,False);assert not target.exists()
 for label,modified in [('partition',text.replace('fractions=','fractions=2.,',1)),('matrix',re.sub(r'(matrix_fraction=)\s*[-+\d.E]+',r'\g<1>0.',text,count=1))]:
  p=out/(opt+'-corrupt-'+label+'.nml');p.write_text(modified);run([cexe,p],c,opt+'-corrupt-'+label,False)
assert geometries[0]==geometries[1]and results['O0']==results['O2']
for p in [*providers,Path(__file__),ROOT/'tools/solute/build_macro_geometry_reader.py',ROOT/'tools/solute/legacy_reader_sources.py',S/'b111-macrogeom.csv.gz']:inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())
r=dict(status='ORIGINAL_MACRO112_FIVE_DOMAIN_GEOMETRY_O0_O2_TYPED_PASS',nodes=112,domains=5,results=results,events=events,input_sha256=inputs,original_SWP_preserved=True,original_SWP_sha256=sha((out/'swap.swp').read_bytes()),canonical_initial_state=False,macroinit=False,full_original_Andelst=False,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
