"""Native original-reader mappings, actual production application and generation rejection."""
import argparse,csv,hashlib,json,os,shlex,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE="""* Literal original TTUTIL grammar; two soil layers.
SWSOLU=1
SWMACRO=0
SWSNOW=0
SWHEA=0
SWINCO=1
SWCROP=0
SWBR=0
ISUBLAY ISOILLAY HSUBLAY NCOMP
1 1 1.0 2
2 2 2.0 2
BDENS=1300.,1500.
CPRE=.125
CDRAIN=.25
CMLTB=0.,.2,-3.,.8
DDIF=.0001
LDIS=.01,.02
SWSP=1
FREXP=.5
CREF=1.
KF=.0002,.0004
SWDC=0
"""
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return [{k:float(v) for k,v in x.items()} for x in csv.DictReader(p.open())]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build-O0',type=Path,required=True);ap.add_argument('--build-O2',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report={'status':'RUNNING','events':[],'cases':{},'inputs':{str(p.relative_to(ROOT)):sha(p) for p in [Path(__file__),ROOT/'tests/nut-sol/test_swp_reader.f90',ROOT/'tools/solute/run_column.py']}}
 def persist():(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,positive=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,input=b'',timeout=90);i=len(report['events'])
  (out/f'{i:04d}.stdout').write_bytes(r.stdout);(out/f'{i:04d}.stderr').write_bytes(r.stderr)
  report['events'].append({'command':list(map(str,cmd)),'returncode':r.returncode,'positive':positive,'seconds':time.perf_counter()-t});persist()
  if (r.returncode==0)!=positive:raise AssertionError((cmd,r.stdout.decode(errors='replace'),r.stderr.decode(errors='replace')))
  return r
 variants={'layered':BASE,'linear':BASE.replace('FREXP=.5','FREXP=1.'),'quadratic':BASE.replace('FREXP=.5','FREXP=2.'),
  'scalar':BASE.replace('BDENS=1300.,1500.','BDENS=1300.').replace('KF=.0002,.0004','KF=.0002').replace('LDIS=.01,.02','LDIS=.01'),
  'off':BASE.replace('SWSP=1','SWSP=0').replace('BDENS=1300.,1500.\n',''),
  'deprecated':BASE.replace('CMLTB=0.,.2,-3.,.8','ZC=0.,-3.\nCML=.2,.8'),
  'grammar':BASE.lower().replace('bdens=1300.,1500.','bdens=1.3D3,1.5D3').replace('ldis=.01,.02','ldis=2*.01'),
  'bottom':BASE.replace('CDRAIN=.25','CDRAIN=.25\nSWBOTBC=1\nCSEEP=.75'),
  'decay':BASE.replace('SWHEA=0','SWHEA=1').replace('SWDC=0','SWDC=1\nDECPOT=.001,.002\nGAMPAR=.05\nRTHETA=.3\nBEXP=1.\nFDEPTH=1.,.5'),
  'heat_off_decay':BASE.replace('SWDC=0','SWDC=1\nDECPOT=.001,.002\nGAMPAR=.05\nRTHETA=.3\nBEXP=1.\nFDEPTH=1.,.5'),
  'crop':BASE.replace('SWCROP=0','SWCROP=1\nTSCF=.5')}
 bad={'macro':('SWMACRO=0','SWMACRO=1'),'snow':('SWSNOW=0','SWSNOW=1'),'aquifer':('SWBR=0','SWBR=1'),
  'analytic_heat':('SWHEA=0','SWHEA=2'),'loose_restart':('SWINCO=1','SWINCO=3'),'crop_branch':('SWCROP=0','SWCROP=2'),
  'bottom_dynamic':('CDRAIN=.25','CDRAIN=.25\nSWBOTBC=2'),'wrong_grid':('2 2 2.0 2','2 2 3.0 2'),
  'wrong_nodes':('2 2 2.0 2','2 2 2.0 3'),'array_short':('KF=.0002,.0004','KF=1*.0002'),
  'array_long':('KF=.0002,.0004','KF=3*.0002'),'density_range':('BDENS=1300.,1500.','BDENS=1.3,1.5'),
  'missing_density':('BDENS=1300.,1500.',''),'exponent_low':('FREXP=.5','FREXP=.49'),
  'exponent_high':('FREXP=.5','FREXP=2.01'),'zero_cref':('CREF=1.','CREF=0.'),
  'mixed_type':('CMLTB=0.,.2,-3.,.8','CMLTB=0,.2,-3,.8'),
  'reverse_table':('CMLTB=0.,.2,-3.,.8','CMLTB=-3.,.2,0.,.8'),
  'duplicate_table':('CMLTB=0.,.2,-3.,.8','CMLTB=0.,.2,0.,.8')}
 for opt in ['O0','O2']:
  build=getattr(a,'build_'+opt).resolve();meta=json.loads((build/'build-complete.json').read_text())
  assert meta['executable_sha256']==sha(build/'swap5_solute_column')
  for p,h in meta['input_sha256'].items():assert sha(ROOT/p)==h,p
  for p,h in meta['generated_input_sha256'].items():assert sha(build/p)==h,p
  report.setdefault('builds',{})[opt]=meta;directory=out/opt;directory.mkdir()
  fc=meta['compiler_command'];driver=directory/'reader'
  objects=[build/f'{i:04d}.o' for i in range(meta['provider_count']-1)]
  run(fc+meta['flags']+[ROOT/'tests/nut-sol/test_swp_reader.f90']+objects+[build/'libttutil.a','-o',driver],directory)
  for name,text in variants.items():
   case=directory/name;case.mkdir();swp=case/'source.swp';swp.write_text(text)
   heat=name=='decay'
   r=run([driver,swp.name,'heat' if heat else 'off'],case);lines=r.stdout.decode().splitlines()
   scalar=list(map(float,next(x for x in lines if x.startswith('SCALARS ')).split()[1:]))
   vectors=[list(map(float,x.split()[2:])) for x in lines if x.startswith('NODE ')]
   faces=list(map(float,next(x for x in lines if x.startswith('FACES ')).split()[1:]))
   assert max(abs(x-y) for x,y in zip(scalar[:3],[.125,.25,.75 if name=='bottom' else .25]))<1e-14
   assert scalar[5]==(.5 if name=='crop' else 0.)
   for i,v in enumerate(vectors):
    layer=i//2;density=1.3 if name in ['scalar','off'] or layer==0 else 1.5
    kf=0. if name=='off' else (.2 if name=='scalar' or layer==0 else .4)
    assert abs(v[0]-[.25,.35,.5,.7][i])<1e-14
    assert abs(v[1]-density)<1e-14 and abs(v[2]-kf)<1e-14
    assert abs(v[8]-density*kf)<1e-14
    decay=name in ['decay','heat_off_decay']
    assert abs(v[3]-([.001,.002][layer] if decay else 0.))<1e-14
    assert abs(v[4]-([1.,.5][layer] if decay else 0.))<1e-14
    assert max(abs(x-y) for x,y in zip(v[5:8],[.05,.3,1.] if decay else [0.,.5,0.]))<1e-14
   assert faces==([.01]*3 if name in ['scalar','grammar'] else [.01,.01,.02])
   source=case/'input.nml'
   textn=(ROOT/'examples/solute_column/positive_pond.nml').read_text()
   if heat:textn=textn.replace('schema=1','schema=1, dynamic_temperature=.true.')
   source.write_text(textn)
   common=[sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',source,'--swp',swp]
   for target,extra in [('full',[]),('split',['--stop-after','1']),('resumed',['--restart',case/'split'])]:
    run(common+['--output',case/target]+extra,case)
   for p in ['state.csv','endpoint.csv','restart.bin']+(['temperature.csv'] if heat else []):assert (case/'full'/p).read_bytes()==(case/'resumed'/p).read_bytes(),p
   budget=rows(case/'full/budget.csv')
   theta=.032+(.423-.032)/(1.+(.0135*75.)**1.455)**(1.-1./1.455)
   original_initial=.25+sum((theta*c+rho_kf*scalar[4]*(c/scalar[4])**scalar[3])*dz
       for c,rho_kf,dz in zip([.25,.35,.5,.7],[v[8] for v in vectors],[.5,.5,1.,1.]))
   assert abs(budget[0]['solute_start_mg_cm2']-original_initial)<1e-12
   for b in budget:assert abs(b['water_residual_cm'])<1e-10 and abs(b['solute_residual_mg_cm2'])<1e-11
   for i,b in enumerate(rows(case/'full/state.csv')):
    want=vectors[i][8]*scalar[4]*(b['concentration_mg_cm3']/scalar[4])**scalar[3]*b['dz_cm']
    assert abs(b['sorbed_mg_cm2']-want)<1e-11
   manifest=json.loads((case/'full/manifest.json').read_text());assert manifest['swp_sha256']==sha(swp)
   assert set(p.name for p in (case/'full').iterdir())==set(manifest['files'])|{'manifest.json'}
   # Provenance rejects missing, edited and damaged SWP before any native state.
   for label,edit in [('missing',None),('changed',text+'\n* changed bytes\n')]:
    c=common.copy()
    if edit is None:c=c[:-2]
    else:
     changed=case/'changed.swp';changed.write_text(edit);c[-1]=changed
    target=case/('bad-'+label);r=run(c+['--output',target,'--restart',case/'split'],case,False)
    assert b'restart SWP identity mismatch' in r.stderr and not target.exists()
   report['cases'][opt+'-'+name]={'scalar':scalar,'vectors':vectors,'faces':faces,'restart_sha256':sha(case/'full/restart.bin'),'budget':rows(case/'full/budget.csv')};persist()
  for name,(old,new) in bad.items():
   case=directory/('bad-'+name);case.mkdir();swp=case/'source.swp';swp.write_text(BASE.replace(old,new));target=case/'output'
   run([sys.executable,ROOT/'tools/solute/run_column.py','--exe',build/'swap5_solute_column','--input',ROOT/'examples/solute_column/positive_pond.nml','--swp',swp,'--output',target],case,False);assert not target.exists()
  assert (directory/'layered/full/state.csv').read_bytes()==(directory/'heat_off_decay/full/state.csv').read_bytes()
 for name in variants:assert report['cases']['O0-'+name]==report['cases']['O2-'+name],name
 report['status']='ORIGINAL_SWP_CHEMISTRY_O0_O2_MAPPING_BALANCE_RESTART_REJECTION_PASS';persist();print(report['status'])
if __name__=='__main__':main()
