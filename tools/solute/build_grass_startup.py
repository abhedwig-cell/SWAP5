#!/usr/bin/env python3
"""Build the source-input Grassgrowth startup application, real Reference kernel.

Uses only TTUTIL and historical table-reading helpers from the original sources.
The complete original SWAP model is never linked into this application.
"""
import argparse,base64,hashlib,io,json,os,re,shutil,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--optimization',choices=['O0','O2'],required=True)
p.add_argument('--profile',choices=['checked','production'],default='checked')
p.add_argument('--reuse-build',type=Path)
p.add_argument('--compiler',type=Path,default=Path(shutil.which('gfortran') or 'gfortran'))
p.add_argument('--input-archive',type=Path,help='Optional already-built original TTUTIL archive; otherwise build from the pinned repository authority')
p.add_argument('--end',type=float,default=.01)
p.add_argument('--policy',choices=['ordinary','retained'],default='ordinary')
p.add_argument('--numerical-profile',choices=['water-only','thermal-control-1e-5C'],default='water-only')
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
assert a.numerical_profile=='water-only' or a.policy=='retained','thermal profile requires retained proposal policy'
fc=str(a.compiler.resolve());archive=a.input_archive.resolve() if a.input_archive else out/'libttutil.a'
if a.input_archive:assert archive.is_file()
authority=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(authority.read_bytes())),mode='r:gz')as t:
 original=t.extractfile('SWAP/functions.f90').read().decode('latin1')
helpers=''
for name in ['afgen_2','rdadortb']:
 match=re.search(r'^\s*subroutine '+name+r'\b.*?^\s*end subroutine '+name+r'\b',original,re.M|re.S|re.I)
 assert match;helpers+=match.group()+'\n'
helper=out/'original_input_helpers.f90';helper.write_text(helpers)
context=ROOT/'app/solute_column/link_context.f90';driver=ROOT/'app/grass_project/initial_interval.f90'
mapping={}
for source in list((ROOT/'src').rglob('*.f90'))+[context,ROOT/'app/solute_column/read_swp_water.f90',ROOT/'app/solute_column/read_swp_heat.f90']+list((ROOT/'app/grass_project').glob('*.f90')):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',source.read_text(),re.M|re.I):
  key=name.lower();assert key not in mapping,(key,source,mapping.get(key));mapping[key]=source
ordered=[];seen=set();active=set()
def visit(source):
 if source in seen:return
 assert source not in active,source
 active.add(source)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',source.read_text(),re.M|re.I):
  key=name.lower()
  if key in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
  assert key in mapping,(key,source)
  if mapping[key]!=source:visit(mapping[key])
 active.remove(source);seen.add(source);ordered.append(source)
visit(driver);ordered.remove(driver)
visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')
publication=ROOT/'app/support/restart_publish.c'
ordered += [helper,publication,driver]
flags=['-'+a.optimization,'-ffree-line-length-none','-fopenmp']+(['-fcheck=all']if a.profile=='checked'else[])+['-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out)]
c_flags=['-'+a.optimization,'-std=c11','-Wall','-Wextra','-Werror']
hashes={str(s):sha(s)for s in ordered}
report=dict(status='BUILDING',profile=a.profile,compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],
 source_sha256=hashes,original_input_archive_sha256=sha(archive) if a.input_archive else None,source_authority_sha256=sha(authority),flags=flags,
 publication_c_flags=c_flags,build_recipe_sha256=sha(Path(__file__)),events=[])
def save():(out/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
def run(command,label,cwd=out,timeout=120):
 start=time.perf_counter();i=len(report['events'])
 try:r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=timeout);rc=r.returncode
 except subprocess.TimeoutExpired as e:r=e;rc=None
 (out/(str(i)+'.stdout')).write_bytes(r.stdout or b'');(out/(str(i)+'.stderr')).write_bytes(r.stderr or b'')
 report['events'].append(dict(label=label,command=list(map(str,command)),seconds=time.perf_counter()-start,returncode=rc));save()
 return rc
if not a.input_archive:
 from legacy_reader_sources import materialize, original_input_compile_flags
 _,providers=materialize(ROOT,out)
 ttout=out/'ttobj';ttout.mkdir();ttobjects=[]
 legacy_flags=['-'+a.optimization,'-std=legacy','-fallow-argument-mismatch','-ffree-line-length-none',
               '-ffixed-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',
               '-I'+str(ttout),'-J'+str(ttout)]
 report['original_input_sources_sha256']={str(s):sha(s)for s in providers}
 report['original_input_flags']=legacy_flags
 report['original_input_flags_by_source']={}
 for i,source in enumerate(providers):
  obj=ttout/(str(i)+'.o')
  selected_flags=original_input_compile_flags(legacy_flags,source)
  report['original_input_flags_by_source'][str(source.relative_to(out))]=selected_flags
  assert run([fc,*selected_flags,'-c',source,'-o',obj],'compile_original_input')==0,source
  ttobjects.append(obj)
 ar=subprocess.check_output([fc,'-print-prog-name=ar'],text=True).strip()
 assert run([ar,'rcs',archive,*[o.name for o in ttobjects]],'archive_original_input',ttout)==0
 report['original_input_archive_sha256']=sha(archive)
 report['original_input_objects_sha256']={str(o):sha(o)for o in ttobjects}
objects=[];changed=set();reuse={};reused_artifacts={}
if a.reuse_build:
 import shutil
 baseline=a.reuse_build.resolve();old=json.loads((baseline/'BUILD.json').read_text())
 assert old['compiler']==report['compiler']
 assert old.get('publication_c_flags')==c_flags,'native publication compiler profile mismatch'
 assert [f for f in flags if not f.startswith(('-I','-J'))]==[f for f in old['flags']if not f.startswith(('-I','-J'))],'code-generation profile mismatch'
 assert all(sha(Path(o))==h for o,h in old['object_sha256'].items())
 old_objects=list(old['object_sha256'])
 for i,(name,h)in enumerate(old['source_sha256'].items()):
  key='generated:helpers'if Path(name).name=='original_input_helpers.f90'else name
  reuse[key]=(h,Path(old_objects[i]))
 for f in baseline.glob('*.mod'):shutil.copyfile(f,out/f.name)
for i,source in enumerate(ordered):
 key='generated:helpers'if source==helper else str(source)
 dependencies={mapping[n.lower()]for n in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',source.read_text(),re.M|re.I)if n.lower()in mapping}
 if key in reuse and reuse[key][0]==sha(source)and not dependencies&changed:
  obj=reuse[key][1];objects.append(obj);reused_artifacts[str(obj)]=sha(obj);continue
 changed.add(source)
 source_flags=c_flags if source==publication else flags
 obj=out/(str(i)+'.o');command=[fc,*source_flags,'-c',source,'-o',obj]
 rc=run(command,'compile')
 assert rc==0,(source,rc)
 if not obj.is_file()or obj.stat().st_size==0:rc=run(command,'retry_empty_artifact')
 assert rc==0 and obj.stat().st_size>0,(source,rc)
 objects.append(obj)
assert all(sha(Path(s))==h for s,h in hashes.items()),'source changed during build'
exe=out/('swap5_grass_startup.exe' if os.name=='nt' else 'swap5_grass_startup')
assert run([fc,'-fopenmp',*objects,archive,'-o',exe],'link')==0
report.update(status='BUILT',provider_count=len(ordered),executable=exe.name,executable_sha256=sha(exe),object_sha256={str(o):sha(o)for o in objects},reused_artifacts_sha256=reused_artifacts,module_sha256={str(f):sha(f)for f in out.glob('*.mod')});save()
project=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth';case=out/'original-interval';case.mkdir()
for source,target in [('swap.swp','input.swp'),('grass.crp','grass.crp'),('260.met','input.met'),('swap.bbc','swap.bbc'),('swap.dra','swap.dra')]:
 (case/target).write_bytes((project/source).read_bytes())
report['original_inputs_sha256']={s.name:sha(s)for s in case.iterdir()}
binding_data=dict(executable_sha256=sha(exe),compiler=report['compiler'],source_sha256=hashes)
if a.numerical_profile!='water-only':binding_data['grass_numerical_profile']=a.numerical_profile
binding=json.dumps(binding_data,sort_keys=True).encode()
(case/'application.binding').write_bytes(binding)
report['application_binding_sha256']=sha(case/'application.binding')
command=[exe,str(a.end)]+(['retain-step']if a.policy=='retained'else[])
if a.numerical_profile!='water-only':command=[exe,str(a.end),'retain-step','100000','','thermal-control']
rc=run(command,'native_original_initial_interval',case,60)
report['grass_numerical_profile']=a.numerical_profile
report['native_returncode']=rc
report['original_project_completed_days']=a.end if rc==0 else 0
report['requested_end']=a.end;report['numerical_policy']=a.policy
report['status']='ORIGINAL_INTERVAL_COMPLETED'if rc==0 else'ORIGINAL_INTERVAL_BLOCKED'
save();print(json.dumps({k:report[k]for k in ['status','provider_count','native_returncode','original_project_completed_days']}))
