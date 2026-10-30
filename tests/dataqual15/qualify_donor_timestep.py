"""Refine only donor DTMAX with the authentic sealed original executable.

The literal .04-day run must reproduce all1827 stored scalar rows exactly.
Smaller DTMAX values are disclosed numerical counterfactuals, not replacements
for the original-input reference or new original-project qualifications.
"""
import argparse,csv,hashlib,io,json,math,re,struct,subprocess,tarfile,time
from checkpoint_layout import layout
from pathlib import Path
from grass_full_capsule import ROOT,verify
sha=lambda raw:hashlib.sha256(raw).hexdigest()
FIELDS={'WTOT':('budget','water_end_cm',1e-9,'cm'),'TPOT':('budget','potential_cm',1e-9,'cm/day'),'TACT':('budget','uptake_cm',1e-9,'cm/day'),'TREDWET':('budget','oxygen_cm',1e-9,'cm/day'),'TREDDRY':('budget','drought_cm',1e-9,'cm/day'),'WRT':('crop','wrt',1e-6,'kg/ha'),'WLV':('crop','wlv',1e-6,'kg/ha'),'WST':('crop','wst',1e-6,'kg/ha'),'RD':('crop','rd',1e-7,'cm'),'PWRT':('crop','pwrt',1e-6,'kg/ha'),'RDPOT':('crop','rdpot',1e-7,'cm'),'DVS':('crop','dvs',1e-8,'dimensionless'),'TSUM':('crop','tsum',1e-8,'degree day')}
CONTROLS={'PWRT','RDPOT','DVS','TSUM','PHRVDM_PROJECT'}
def project_counter(rows,key):
 carry=0.;values=[]
 for day,row in enumerate(rows):
  if day and row['DATE'][:4]!=rows[day-1]['DATE'][:4]:carry+=float(rows[day-1][key])
  values.append(carry+float(row[key]))
 return values

def vectors(rows,profile,budget,crop,checkpoints):
 native={};reference={};units={};floors={}
 for field,(kind,column,floor,unit)in FIELDS.items():
  native[field]=[float(row[column])for row in(budget if kind=='budget'else crop)]
  reference[field]=[float(row[field])for row in rows[1:]];units[field]=unit;floors[field]=floor
 eligible=[day for day in range(1,len(rows))if day>1 and rows[day]['DATE'][:4]==rows[day-1]['DATE'][:4]]
 native['LAI_DAY_START']=[float(crop[day-1]['lai'])for day in eligible];reference['LAI_DAY_START']=[float(rows[day-1]['LAI'])for day in eligible];units['LAI_DAY_START']='m2/m2';floors['LAI_DAY_START']=1e-8
 for key,offset in [('HRVDM_PROJECT',4),('PHRVDM_PROJECT',12)]:
  totals=project_counter(rows,key.split('_')[0]);native[key]=[];reference[key]=[]
  for day,raw in sorted(checkpoints.items()):
   state=layout(raw);native[key].append(struct.unpack_from('=d',raw,state['management']+offset)[0]);reference[key].append(totals[day])
  units[key]='kg/ha';floors[key]=1e-6
 native['NET_FLUX']= [float(row['input_cm'])-float(row['output_cm'])for row in budget]
 reference['NET_FLUX']=[sum(float(row[key])for key in ['RAIN','IRRIG','SSDI','BOT'])-sum(float(row[key])for key in ['EIC','EACT','TACT','EPD','RUNOFF','DRN'])for row in rows[1:]];units['NET_FLUX']='cm/day';floors['NET_FLUX']=1e-9
 for field,floor,unit in [('head_cm',1e-8,'normalized by max(1cm,abs(h))'),('water_content',1e-12,'cm3/cm3'),('temperature_c',1e-9,'C')]:
  name='PROFILE_'+field;native[name]=[];reference[name]=[]
  for day,raw in sorted(checkpoints.items()):
   if day not in profile:continue
   state=layout(raw);n=state['nodes'];pos=state['physical']+{'head_cm':0,'water_content':8*n,'temperature_c':16*n+16}[field]
   native[name]+=list(struct.unpack_from('='+str(n)+'d',raw,pos));reference[name]+=[float(row[field])for row in sorted(profile[day],key=lambda row:int(row['node']))]
  assert native[name]and len(native[name])==len(reference[name]);units[name]=unit;floors[name]=floor
 return native,reference,units,floors

def distance(key,left,right):
 assert len(left)==len(right)and left
 return max(abs(a-b)/(max(1.,abs(a),abs(b))if key=='PROFILE_head_cm'else 1.)for a,b in zip(left,right))

def register_envelope(coarse,fine,pc,pf,budget,crop,checkpoints):
 native,c,units,floors=vectors(coarse,pc,budget,crop,checkpoints);_,f,_,_=vectors(fine,pf,budget,crop,checkpoints)
 bounds={}
 for key in native:
  change=distance(key,c[key],f[key]);bounds[key]=dict(unit=units[key],floor=floors[key],training_change=change,limit=floors[key]if key in CONTROLS else 3*change+floors[key])
 return dict(scope='CONDITIONAL_NUMERICAL_RESOLUTION_ENVELOPE_NOT_ECOLOGICAL_MODEL_ERROR_BOUND',training_dtmax_days=[.005,.0025],rule='Freeze three times the observed coarse/fine sup-norm change plus a source-print/floating-point floor. Independent potential controls use the floor alone. Both held-out halvings must reduce the reference change and place native errors within each frozen envelope.',pressure_metric='Same normalized pressure metric as the admitted experimental temporal owner; absolute pressure errors remain diagnostic.',LAI_phase='Native day-start LAI versus donor previous-day end LAI, excluding annual initializations',profile_scope='Only retained113-node checkpoint dates; no full energy-equivalence claim',bounds=bounds,scientific_equivalence=False)

def assess_envelope(registration,old,new,po,pn,budget,crop,checkpoints,previous_change):
 native,o,_,_=vectors(old,po,budget,crop,checkpoints);_,n,_,_=vectors(new,pn,budget,crop,checkpoints)
 changes={key:distance(key,o[key],n[key])for key in native};errors={key:distance(key,native[key],n[key])for key in native}
 fields={key:dict(native_error=errors[key],limit=bound['limit'],reference_change=changes[key],previous_reference_change=previous_change[key],inside_frozen_envelope=errors[key]<=bound['limit'],reference_change_decreases=changes[key]<=previous_change[key]+bound['floor'])for key,bound in registration['bounds'].items()}
 return dict(fields=fields,reference_change=changes,**{'pass':all(value['inside_frozen_envelope']and value['reference_change_decreases']for value in fields.values())})

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--profiles',action='store_true');a=p.parse_args()
 capsule=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz';manifest=ROOT/'integration/dataqual15/GRASS_UNION_FULL_MANIFEST.json'
 verify(capsule,manifest)
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 with tarfile.open(capsule,'r:xz')as tar:
  spec=json.load(tar.extractfile('SPEC.json'));base=spec['reference_B0']
  binary=tar.extractfile('original431/swap431_profiles'if a.profiles else'original431/swap431').read()
  inputs={name:tar.extractfile(base+'/'+name).read()for name in ['swap.swp','grass.crp','260.met','swap.bbc','swap.dra']}
  baseline=tar.extractfile(base+'/result_output.csv').read().decode()
  expected_profile=list(csv.DictReader(io.StringIO(tar.extractfile(spec['reference_B0_nodal']+'/original/nodal_profiles.csv').read().decode())))if a.profiles else None
  native_budget=list(csv.DictReader(io.StringIO(tar.extractfile(spec['full']+'/budget.csv').read().decode())))
  native_crop=list(csv.DictReader(io.StringIO(tar.extractfile(spec['full']+'/crop.csv').read().decode())))
  checkpoints={}
  for name in tar.getnames():
   if name.startswith(spec['full']+'/checkpoint')and name.endswith('.bin'):
    raw=tar.extractfile(name).read();checkpoints[int(layout(raw)['clock'])]=raw
 executable=out/'swap431';executable.write_bytes(binary);executable.chmod(0o755)
 scalar=lambda text:list(csv.DictReader(line for line in text.splitlines()if line.strip()and not line.startswith('*')))
 expected=scalar(baseline)
 pattern=re.compile(r'(?im)^(\s*DTMAX\s*=\s*)([\d.eE+\-]+)([^\r\n]*)$')
 text=inputs['swap.swp'].decode();matches=list(pattern.finditer(text));assert len(matches)==1 and float(matches[0][2])==.04
 physical=lambda value:pattern.sub(r'\1NUMERICAL_DTMAX\3',value)
 report=dict(status='RUNNING',scope='DONOR_NUMERICAL_COUNTERFACTUAL_NOT_NEW_ORIGINAL_PROJECT',physical_input_changes=False,executable_sha256=sha(binary),capsule_sha256=sha(capsule.read_bytes()),runs={},scientific_equivalence=False)
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 measured=None;series={};profiles={};registration=None;previous_change=None
 caps=[.04,.005,.0025,.00125,.000625]if a.profiles else[.04,.02,.01,.005,.0025]
 for cap in caps:
  case=out/('dtmax-'+str(cap));case.mkdir()
  changed=text if cap==.04 else pattern.sub(lambda m:m[1]+str(cap)+m[3],text)
  assert physical(changed)==physical(text)
  for name,raw in inputs.items():(case/name).write_bytes(changed.encode()if name=='swap.swp'else raw)
  budget=240 if measured is None else max(240,math.ceil(measured*.04/cap*3+60))
  record=dict(dtmax_day=cap,numerical_input_changes=[]if cap==.04 else['DTMAX'],physical_input_changes=False,wall_cap_seconds=budget,input_sha256={name:sha((case/name).read_bytes())for name in inputs})
  report['runs'][str(cap)]=record;save();print('DONOR_DTMAX_START',cap,'cap_seconds',budget,flush=True)
  start=time.monotonic()
  with (case/'stdout').open('wb')as stdout,(case/'stderr').open('wb')as stderr:
   try:r=subprocess.run([str(executable)],cwd=case,stdout=stdout,stderr=stderr,timeout=budget);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  record.update(returncode=code,censored=censored,seconds=time.monotonic()-start);save()
  assert code==100 and not censored and(case/'swap.ok').exists(),record
  rows=scalar((case/'result_output.csv').read_text());assert len(rows)==1828 and rows[-1]['DATE']=='1984-12-31'
  if cap==.04:assert rows==expected,'unmodified same-binary donor trajectory differs';measured=record['seconds']
  annual=[]
  for day,row in enumerate(rows):
   if day and(day==1827 or rows[day+1]['DATE'][:4]!=row['DATE'][:4]):annual.append(float(row['HRVDM']))
  record.update(completed_days=1827,scalar_sha256=sha((case/'result_output.csv').read_bytes()),literal_reference_exact=cap==.04,project_actual_harvest_kg_ha=math.fsum(annual),selected_days={str(day):{key:float(rows[day][key])for key in ['TPOT','TACT','TREDWET','TREDDRY','WRT','WLV','HRVDM','WTOT']}for day in [25,72,73,127,140,367,1827]})
  series[cap]=rows
  if a.profiles:
   profile_rows=list(csv.DictReader((case/'nodal_profiles.csv').open()));profiles[cap]={}
   if cap==.04:assert profile_rows==expected_profile,'same-binary unmodified donor nodal trajectory differs'
   for row in profile_rows:profiles[cap].setdefault(int(row['day']),[]).append(row)
   record['profiles_sha256']=sha((case/'nodal_profiles.csv').read_bytes())
   if cap==.0025:
    registration=register_envelope(series[.005],series[.0025],profiles[.005],profiles[.0025],native_budget,native_crop,checkpoints)
    registration['registered_before_holdout_dtmax_days']=[.00125,.000625]
    registration['training_scalar_sha256']={str(value):report['runs'][str(value)]['scalar_sha256']for value in [.005,.0025]}
    registration['training_profiles_sha256']={str(value):report['runs'][str(value)]['profiles_sha256']for value in [.005,.0025]}
    registration['script_sha256']=sha(Path(__file__).read_bytes())
    (out/'PREREGISTRATION.json').write_text(json.dumps(registration,indent=2)+'\n',newline='\n')
    report['preregistration_sha256']=sha((out/'PREREGISTRATION.json').read_bytes());previous_change={key:value['training_change']for key,value in registration['bounds'].items()}
   if cap<.0025:
    old=.0025 if cap==.00125 else .00125
    assessment=assess_envelope(registration,series[old],rows,profiles[old],profiles[cap],native_budget,native_crop,checkpoints,previous_change)
    record['resolution_assessment']=assessment;previous_change=assessment['reference_change']
  save();print('DONOR_DTMAX_COMPLETE',cap,'seconds',record['seconds'],'harvest',record['project_actual_harvest_kg_ha'],flush=True)
 if a.profiles:report['numerical_resolution_gate_pass']=all(report['runs'][str(value)]['resolution_assessment']['pass']for value in [.00125,.000625])
 report['status']='DONOR_TIMESTEP_REFINEMENT_MEASURED';save();print(json.dumps(report,indent=2))
if __name__=='__main__':main()
