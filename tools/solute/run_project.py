#!/usr/bin/env python3
"""Run one original SWP-led daily ETref/simple-crop project atomically."""
import argparse,base64,csv,hashlib,io,json,math,re,subprocess,sys,tempfile
from pathlib import Path
from run_crop_daily import check_reader
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def resolve_file(folder,name):
 name=name.replace('\\','/').strip();path=Path(name)
 if re.match(r'^[A-Za-z]:',name):raise ValueError('Windows drive path cannot be resolved on this host: '+name)
 path=path if path.is_absolute() else folder/path
 if path.is_file():return path.resolve()
 # The historical reader lowercases names. Resolve only a unique actual path,
 # component by component; never choose one of ambiguous case-only duplicates.
 absolute=path.absolute();current=Path(absolute.anchor)
 for part in absolute.parts[1:]:
  if part=='.':continue
  if part=='..':current=current.parent;continue
  if not current.is_dir():raise FileNotFoundError(path)
  hits=[p for p in current.iterdir()if p.name.casefold()==part.casefold()]
  if len(hits)!=1:raise ValueError('missing or ambiguous project reference: '+str(path))
  current=hits[0]
 if not current.is_file():raise FileNotFoundError(current)
 return current.resolve()
def native(exe,args,stage,marker):
 cp=subprocess.run([str(exe),*args],cwd=stage,input=b'',capture_output=True,timeout=60)
 if cp.returncode or marker not in cp.stdout:
  raise ValueError('native project preparation rejected:\n'+cp.stdout.decode(errors='replace')+cp.stderr.decode(errors='replace'))
 return cp
def prepare(bundle,swp,temporal_tolerance):
 if not math.isfinite(temporal_tolerance) or temporal_tolerance<=0:raise ValueError('positive finite temporal tolerance required')
 executables={k:Path(bundle[k]).resolve()for k in ['project_reader','crop_reader','root_reader','exe']}
 if bundle.get('schema')!=1 or bundle.get('status')!='BUILT':raise ValueError('invalid build bundle')
 metadata={k:check_reader(p)for k,p in executables.items()}
 if any(sha(p.read_bytes())!=bundle['executable_sha256'][str(p)]for p in executables.values()):raise ValueError('changed bundle executable')
 swp_bytes=swp.read_bytes();sources=[('original_swp',swp_bytes)];prepared=[]
 with tempfile.TemporaryDirectory(prefix='swap5-project-input-')as tmp:
  stage=Path(tmp);(stage/'input.swp').write_bytes(swp_bytes)
  native(executables['project_reader'],['input.swp','scan'],stage,b'SWP_NATIVE_PROJECT_SCANNED')
  references=list(csv.DictReader((stage/'project.csv').open()))
  paths={r['kind']:r['value'].strip()for r in references if r['kind']in ['pathatm','pathcrop']}
  for r in references:
   if r['kind']not in ['met','crop']:continue
   kind=r['kind'];folder=paths['pathatm'if kind=='met'else'pathcrop'].replace('\\','/').strip()
   name=(Path(folder)/r['value'])if folder else Path(r['value'])
   path=resolve_file(swp.parent,str(name));raw=path.read_bytes();sources.append((kind+'_'+r['index'],raw))
   (stage/(('weather-'if kind=='met'else'crop-')+r['index']+('.met'if kind=='met'else'.crp'))).write_bytes(raw)
  native(executables['project_reader'],['input.swp','prepare'],stage,b'SWP_NATIVE_PROJECT_PREPARED')
  for r in references:
   if r['kind']!='crop':continue
   index=r['index'];names=['period-'+index+'.swp','crop-'+index+'.crp','weather.met']
   native(executables['crop_reader'],names,stage,b'SWP_NATIVE_SIMPLE_CROP_PREPARED')
   native(executables['root_reader'],names,stage,b'SWP_NATIVE_ROOT_IMPORTED')
   plan=list(csv.DictReader((stage/'crop_daily.csv').open()));rain=list(csv.DictReader((stage/'rain.csv').open()))
   if not plan or len(plan)!=len(rain)or any(float(a['t1900'])!=float(b['t1900'])for a,b in zip(plan,rain)):raise ValueError('foreign crop/rain calendar')
   prepared.append(dict(index=int(index),plan=plan,rain=rain,root=(stage/'root.nml').read_text()))
   (stage/'crop_daily.csv').unlink();(stage/'root.nml').unlink();(stage/'rain.csv').unlink()
  weather=(stage/'weather.met').read_bytes()
 if not prepared:raise ValueError('no crop periods')
 combined=[dict(row)for row in prepared[0]['plan']];indices=[0]*len(combined)
 for row in combined:
  for key in ['active','dvs','lai','cover','root_depth_cm','transpiration_cm_day']:row[key]='0'
 for period in prepared:
  if len(period['plan'])!=len(combined)or period['rain']!=prepared[0]['rain']:raise ValueError('period weather mismatch')
  for i,row in enumerate(period['plan']):
   if float(row['t1900'])!=float(combined[i]['t1900']):raise ValueError('period clock mismatch')
   if float(row['active'])==1:
    if indices[i]!=0:raise ValueError('overlapping crop demand')
    combined[i]=dict(row);indices[i]=period['index']
 # Inactive days need the production bare-soil demand. Every individual period
 # contains that identical fallow view outside its own active growth window.
 for i in range(len(combined)):
  if indices[i]==0:
   fallback=next((p['plan'][i]for p in prepared if float(p['plan'][i]['active'])==0),None)
   if fallback is None:raise ValueError('missing fallow demand')
   combined[i]=dict(fallback)
 comments=['! SWAP5 native SWP-led project route v1','! generator_sha256='+sha(Path(__file__).read_bytes())]
 for key,meta in metadata.items():comments.append('! '+key+'_executable_sha256='+meta['executable_sha256'])
 for name,raw in sources:
  comments.append('! '+name+'_sha256='+sha(raw));encoded=base64.b64encode(raw).decode()
  comments+=['! '+name+'_base64='+encoded[i:i+76]for i in range(0,len(encoded),76)]
 values={r['kind']:float(r['value'])for r in references if r['kind']in ['bottom','pondmax','rsro']}
 lines=comments+['&column',' schema=2,nodes=0,swp_water_bootstrap=.true.',f' temporal_tolerance={temporal_tolerance:.17e}',
  f' bottom_up_cm_day={values["bottom"]:.17e}',f' pond_max_cm={values["pondmax"]:.17e}',f' runoff_resistance_day={values["rsro"]:.17e}',
  '/','&surface',' windows='+str(len(combined)),' ends_day='+','.join(str(i+1)for i in range(len(combined))),
  ' rain_cm_day='+','.join(r['rain_cm_day']for r in prepared[0]['rain']),
  ' soil_evaporation_cm_day='+','.join(r['soil_evaporation_cm_day']for r in combined),
  ' evaporation_cm_day='+','.join(r['pond_evaporation_cm_day']for r in combined),'/']
 first_root=prepared[0]['root'].strip()
 if not first_root.upper().startswith('&CROP')or first_root.count('/')!=1:raise ValueError('foreign root namelist')
 lines+=[first_root[:-1],' substep_root_stress=.true.',
  ' crop_active='+','.join('.true.'if float(r['active'])==1 else'.false.'for r in combined),
  ' potential_transpiration_cm_day='+','.join(r['transpiration_cm_day']for r in combined),
  ' root_depth_cm='+','.join(r['root_depth_cm']for r in combined),'/','&rotation',
  ' profile_count='+str(len(prepared)),' profile_index='+','.join(map(str,indices))]
 for period in prepared:
  body=period['root'].strip()[5:-1]
  body=re.sub(r'\bMAXIMUM_ROOT_DEPTH_CM\s*=\s*[^,\n]+,?','',body,flags=re.I)
  prefix='PROFILES('+str(period['index'])+')%'
  def rename(match):
   key=match.group(1).upper()
   target={'ROOT_TABLE_POINTS':'POINTS','ROOT_RELATIVE_DEPTH':'RELATIVE_DEPTH','ROOT_DENSITY':'DENSITY'}.get(key)
   if target is None:
    if key not in ['UPPER_LAYER_BOTTOM_NODE','HLIM3L','HLIM3H','HLIM4','ADCRL','ADCRH','HLIM1','HLIM2U','HLIM2L','EMPIRICAL_OXYGEN_ENABLED']:raise ValueError('unknown native root field '+key)
    target='PARAMETERS%'+key
   return prefix+target+'='
  lines.append(re.sub(r'\b([A-Z_0-9]+)\s*=',rename,body,flags=re.I))
 lines+=['/']
 audit=dict(schema=1,route='NATIVE_SWP_SIMPLE_CROP_ROTATION_ETREF',original_sources={name:sha(raw)for name,raw in sources},
  normalized_weather_sha256=sha(weather),periods=len(prepared),days=len(combined),profile_index=indices,prepared_periods=prepared)
 return '\n'.join(lines)+'\n',swp_bytes,audit,executables['exe']
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('swp',type=Path);ap.add_argument('--bundle',type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);ap.add_argument('--restart',type=Path);ap.add_argument('--stop-after',type=int,default=2048)
 ap.add_argument('--temporal-tolerance',type=float,default=1e-4);a=ap.parse_args()
 if a.output.exists():raise FileExistsError(a.output)
 bundle=json.loads((a.bundle/'bundle.json'if a.bundle.is_dir()else a.bundle).read_text())
 document,snapshot,audit,exe=prepare(bundle,a.swp.resolve(),a.temporal_tolerance)
 # Keep all audit information inside the already-bound immutable input document;
 # never add an unbound sidecar to the admitted atomic output inventory.
 encoded=base64.b64encode(json.dumps(audit,sort_keys=True).encode()).decode()
 document='\n'.join('! native_project_audit_base64='+encoded[i:i+76]for i in range(0,len(encoded),76))+'\n'+document
 with tempfile.TemporaryDirectory(prefix='swap5-project-run-')as tmp:
  stage=Path(tmp);(stage/'input.nml').write_text(document);(stage/'input.swp').write_bytes(snapshot)
  cmd=[sys.executable,ROOT/'tools/solute/run_column.py','--exe',exe,'--input',stage/'input.nml','--swp',stage/'input.swp',
       '--output',a.output.resolve(),'--stop-after',str(a.stop_after)]
  if a.restart:cmd+=['--restart',a.restart.resolve()]
  subprocess.run(list(map(str,cmd)),check=True)
if __name__=='__main__':main()
