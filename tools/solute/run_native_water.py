#!/usr/bin/env python3
"""Execute the explicit original SWSOLU0 macro/Rutter/heat water application."""
import argparse,base64,hashlib,json,re,resource,shutil,subprocess,tempfile,time
from pathlib import Path
from run_project import prepare
from run_crop_daily import check_reader
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--memory-mib',type=int,default=1024);p.add_argument('--solver-max-iterations',type=int,default=64);p.add_argument('--perched-jacobian',action='store_true');p.add_argument('--source-surface-demand',action='store_true');p.add_argument('--mode',choices=['production','experimental','comparison'],default='production');p.add_argument('swp',type=Path);p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--restart',type=Path);p.add_argument('--anchored-cauchy',action='store_true');p.add_argument('--entry-ramp-width-cm',type=float,default=0.);p.add_argument('--stop-after',type=int,default=1);p.add_argument('--stop-at-time',type=float);p.add_argument('--temporal-tolerance',type=float,default=.01);p.add_argument('--timeout-seconds',type=float,default=120);a=p.parse_args()
if not 128<=a.memory_mib<=4096:p.error('--memory-mib range is128..4096')
resource.setrlimit(resource.RLIMIT_AS,(a.memory_mib*1024**2,a.memory_mib*1024**2))
if not 1<=a.solver_max_iterations<=256:p.error('--solver-max-iterations range is1..256')
if a.solver_max_iterations!=64 and a.mode!='experimental':p.error('nondefault solver iteration budget requires --mode experimental')
if a.perched_jacobian and a.mode!='experimental':p.error('--perched-jacobian requires --mode experimental')
if a.source_surface_demand and a.mode!='experimental':p.error('--source-surface-demand requires --mode experimental')
assert a.entry_ramp_width_cm==0. or(a.anchored_cauchy and 0.<a.entry_ramp_width_cm<=1e-3),'entry width range/policy'
out=a.output.resolve()
if out.exists():raise FileExistsError(out)
bundle=json.loads((a.bundle/'bundle.json').read_bytes());assert bundle.get('native_water')
document,swp,audit,exe=prepare(bundle,a.swp.resolve(),a.temporal_tolerance,native_hydraulics=True,native_heat=True,native_water=True,experimental_configuration=a.mode=='experimental')
if a.solver_max_iterations!=64:
 document,count=re.subn(r'(&column\b)',lambda m:m[0]+'\n solver_max_iterations='+str(a.solver_max_iterations)+',',document,count=1,flags=re.I)
 assert count==1,'column namelist absent'
if a.perched_jacobian:document+='! numerical_policy=perched-jacobian-diagonal-v1\n'
if a.source_surface_demand:document+='! corrected_source_forcing=original-positive-surface-demand-v1\n'
if a.mode!='production':document+='! execution_mode='+a.mode+'\n'
if a.anchored_cauchy:document+='! native_execution_policy=anchored-cauchy\n'
if a.entry_ramp_width_cm:document+='! corrected_source_entry_transition_width_cm='+repr(a.entry_ramp_width_cm)+'\n'
macro_reader=Path(bundle['macro_reader']);check_reader(macro_reader);assert sha(macro_reader.read_bytes())==bundle['executable_sha256'][str(macro_reader)]
# Exact raw companions are already bound by the existing project preparation.
def original(name):
 matches=re.findall(r'^! '+name+r'_base64=(.*)$',document,re.M);assert matches,name
 raw=base64.b64decode(''.join(matches),validate=True);assert sha(raw)==audit['original_sources'][name];return raw
with tempfile.TemporaryDirectory(prefix='swap5-native-water-',dir=out.parent)as tmp:
 stage=Path(tmp);(stage/'input.nml').write_text(document);(stage/'input.swp').write_bytes(swp)
 for name,source in [('input.bbc','original_bbc'),('input.dra','drain_1')]:
  (stage/name).write_bytes(original(source))
 events=[]
 def run(cmd,label,timeout):
  started=time.monotonic();returncode=None;censored=False;launch_error=None
  with(stage/(label+'.stdout')).open('wb')as so,(stage/(label+'.stderr')).open('wb')as se:
   try:cp=subprocess.run(list(map(str,cmd)),cwd=stage,stdin=subprocess.DEVNULL,stdout=so,stderr=se,timeout=timeout);returncode=cp.returncode
   except subprocess.TimeoutExpired:censored=True
   except OSError as e:launch_error=str(e);se.write((launch_error+"\n").encode())
  event=dict(label=label,command=list(map(str,cmd)),returncode=returncode,censored=censored,launch_error=launch_error,seconds=time.monotonic()-started);events.append(event);return returncode==0 and launch_error is None
 ok=run([macro_reader,'input.swp','input.bbc','macro.nml','input.dra','native-water-experimental'if a.mode=='experimental'else'native-water'],'source_initial',60)
 binding=sha(document.encode()+swp+(stage/'macro.nml').read_bytes()+sha(exe.read_bytes()).encode())if ok else''
 cmd=[exe,'input.nml',str(a.restart.resolve())if a.restart else'-',str(a.stop_after),'input.swp','macro.nml',binding]
 if a.stop_at_time is not None or a.anchored_cauchy or a.mode!='production':cmd.append(str(a.stop_at_time)if a.stop_at_time is not None else'1.7976931348623157e308')
 if a.anchored_cauchy or a.mode!='production':cmd.append('anchored-cauchy'if a.anchored_cauchy else'')
 if a.entry_ramp_width_cm or a.mode!='production':cmd.append(repr(a.entry_ramp_width_cm)if a.entry_ramp_width_cm else'')
 if a.mode!='production':cmd.append(a.mode)
 if a.source_surface_demand or a.perched_jacobian:cmd.append('source-surface-demand'if a.source_surface_demand else'')
 if a.perched_jacobian:cmd.append('perched-jacobian')
 if ok:ok=run(cmd,'native',a.timeout_seconds)
 record=dict(memory_limit_mib=a.memory_mib,status='COMPLETE'if ok else('CENSORED'if events[-1]['censored']else'FAILED'),route='ORIGINAL_SWSOLU0_MACRO_RUTTER_HEAT',mode=a.mode,solver_max_iterations=a.solver_max_iterations,source_surface_demand=a.source_surface_demand,events=events,binding_sha256=binding,stop_after=a.stop_after,preparation=audit,compiler_and_source_bundle=bundle,qualified=False,canonically_admitted=False,files={p.name:sha(p.read_bytes())for p in stage.iterdir()if p.is_file()})
 (stage/'manifest.json').write_text(json.dumps(record,indent=2)+'\n');shutil.copytree(stage,out)
 print(json.dumps(dict(status=record['status'],output=str(out),seconds=sum(e['seconds']for e in events))))
 if not ok:raise SystemExit(1)
