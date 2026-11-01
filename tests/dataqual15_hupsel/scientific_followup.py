"""Full-period Hupsel measurement using immutable native evidence and real originals.

No substitute model, input interpolation, or old-checkpoint rebinding. Only the
original output collector and explicitly labelled numerical DTMAX are varied.
"""
import argparse,collections,csv,difflib,hashlib,io,json,math,re,struct,subprocess,sys,tarfile,time
from pathlib import Path
from inspect_profiles import profile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/dataqual15'))
from original_sources import build_original
CAP=ROOT/'integration/dataqual15_hupsel/UNION_C3_HUPSEL_EVIDENCE.tar.xz'
sha=lambda raw:hashlib.sha256(raw).hexdigest()
rows=lambda raw:list(csv.DictReader(x for x in raw.decode().splitlines()if x.strip()and not x.startswith('*')))

def native_data():
 m=json.loads(CAP.with_name('UNION_C3_HUPSEL_RESULT.json').read_text());assert sha(CAP.read_bytes())==m['archive_sha256']
 with tarfile.open(CAP)as t:
  get=lambda name:t.extractfile(name).read();base='cases/hupsel-full1096/';budget=rows(get(base+'budget.csv'));crop=rows(get(base+'crop.csv'));reference=rows(get('reference/result_output.csv'));points={};hashes={}
  for name in t.getnames():
   if name.startswith(base+'checkpoint')and name.endswith('.bin'):
    raw=get(name);p=profile(raw);points[p['day']]=p;hashes[str(p['day'])]=sha(raw)
  state=rows(get(base+'state.csv'))
  for key in ['z_cm','dz_cm','head_cm','theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2']:assert points[1096][key]==[float(r[key])for r in state]
  grouped=collections.defaultdict(list)
  for r in budget:grouped[int(math.ceil(float(r['t1_day'])-1e-9))].append(r)
  assert sorted(grouped)==list(range(1,1097));daily=[]
  for day,parts in sorted(grouped.items()):
   assert float(parts[0]['t0_day'])==day-1 and float(parts[-1]['t1_day'])==day
   for a,b in zip(parts,parts[1:]):assert a['t1_day']==b['t0_day']
   value={k:math.fsum(float(r[k])for r in parts)for k in parts[0]if k not in ['window','t0_day','t1_day']}
   for k in ['water_start_cm','solute_start_mg_cm2']:value[k]=float(parts[0][k])
   for k in ['water_end_cm','solute_end_mg_cm2']:value[k]=float(parts[-1][k])
   value['day']=day;daily.append(value)
  for r in budget:
   for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
    defect=float(r[prefix+'_end_'+unit])-float(r[prefix+'_start_'+unit])-float(r[prefix+'_in_'+unit])+float(r[prefix+'_out_'+unit]);assert abs(defect)<1e-10
  intervals=[]
  for a,b in zip(sorted(points),sorted(points)[1:]):
   defect={}
   for prefix,unit in [('water','cm'),('solute','mg_cm2')]:
    defect[prefix]=points[b][prefix+'_stock_'+unit]-points[a][prefix+'_stock_'+unit]-math.fsum(r[prefix+'_in_'+unit]-r[prefix+'_out_'+unit]for r in daily[a:b]);assert abs(defect[prefix])<1e-8
   intervals.append(dict(first=a,last=b,residual=defect))
  assert all(all(v==0 for v in p['sorbed_mg_cm2'])for p in points.values())
  supplied=math.fsum(r['solute_in_mg_cm2']for r in daily);exported=math.fsum(r['solute_out_mg_cm2']for r in daily)
  assert abs(supplied-48.)<1e-8 and abs(points[1096]['solute_stock_mg_cm2']+exported-48.)<1e-8
  accounting=dict(window_count=len(budget),full_days=1096,application_mg_cm2=48.,actual_external_input_mg_cm2=supplied,actual_external_output_mg_cm2=exported,independent_final_solute_stock_mg_cm2=points[1096]['solute_stock_mg_cm2'],source_sink_closure_mg_cm2=points[1096]['solute_stock_mg_cm2']+exported-48.,profile_intervals=intervals,all_retained_sorbed_stocks_zero=True,profile_sha256=hashes)
  return daily,crop,points,reference,accounting,get('reference/swap.swp')

def features(reference,profiles,daily,crop,points):
 native={};donor={};floors={};units={}
 mapping={'water_global':('water_end_cm',None,1e-8,'cm'),'solute_stock':('solute_end_mg_cm2','S_STOT',1e-9,'mg/cm2'),
  'potential_transpiration':('potential_transpiration_cm','TPOT',1e-9,'cm/day'),'actual_transpiration':('actual_transpiration_cm','TACT',1e-9,'cm/day'),
  'drought':('drought_reduction_cm','TREDDRY',1e-9,'cm/day'),'oxygen':('oxygen_reduction_cm','TREDWET',1e-9,'cm/day'),'salinity':('salinity_reduction_cm','TREDSOL',1e-9,'cm/day'),
  'soil_evaporation':('soil_evaporation_cm','EACT',1e-9,'cm/day'),'pond_evaporation':('pond_evaporation_cm','EPD',1e-9,'cm/day'),
  'drainage':('drainage_cm','DRN',1e-9,'cm/day'),'runoff':('runoff_cm','RUNOFF',1e-9,'cm/day')}
 for key,(n,d,f,u)in mapping.items():
  native[key]=[r[n]for r in daily];donor[key]=[sum(float(r[k])for k in ['WTOT','PD_VOL','IC_VOL'])if d is None else float(r[d])for r in reference[1:]];floors[key]=f;units[key]=u
 native['solute_net_external']=[r['solute_in_mg_cm2']-r['solute_out_mg_cm2']for r in daily];donor['solute_net_external']=[sum(float(r[k])for k in ['S_RAIN','S_IRRIG'])-sum(float(r[k])for k in ['S_DRN','S_UPT'])for r in reference[1:]];floors['solute_net_external']=1e-9;units['solute_net_external']='mg/cm2/day'
 def exit_features(flux):
  total=math.fsum(flux);assert total>0 and min(flux)>-1e-8
  values={'export_total':[total],'export_fraction_applied':[total/48.],'export_mean_day':[math.fsum((i+1)*q for i,q in enumerate(flux))/total]}
  for fraction in [.1,.5,.9]:
   cumulative=0.
   for day,value in enumerate(flux,1):
    cumulative+=value
    if cumulative>=fraction*total:values['export_q'+str(int(100*fraction))+'_day']=[float(day)];break
  return values
 nf=exit_features([r['solute_out_mg_cm2']for r in daily]);df=exit_features([float(r['S_DRN'])+float(r['S_UPT'])for r in reference[1:]])
 for key,values in nf.items():
  native[key]=values;donor[key]=df[key];floors[key]=1. if key.endswith('_day')else 1e-9;units[key]='day (daily-bin resolution)'if key.endswith('_day')else'mg/cm2 or fraction'
 # Source-inactive negative/sentinel rows are never compared as physiological values.
 for key in ['dvs','tsum','lai','wrt','wlv','wst','wso','pwrt','pwlv','pwst','pwso','rd','rdpot','harvested_dry_matter','potential_harvested_dry_matter']:
  field={'harvested_dry_matter':'HRVDM','potential_harvested_dry_matter':'PHRVDM'}.get(key,key.upper());n=[];d=[]
  for r in crop:
   s=reference[int(r['day'])]
   if float(s['DVS'])<0 or float(s[field])<-900:continue
   n.append(float(r[key]));d.append(float(s[field]))
  assert n;name='crop_'+key;native[name]=n;donor[name]=d;floors[name]=1e-8 if key in ['dvs','tsum','lai']else 1e-7 if key in ['rd','rdpot']else 1e-6;units[name]='source crop units'
 for key,column,floor,unit in [('head_cm','head_cm',1e-8,'normalized cm'),('theta','water_content',1e-12,'cm3/cm3'),('temperature_c','temperature_c',1e-9,'C'),('concentration_mg_cm3','concentration_mg_cm3',1e-10,'mg/cm3')]:
  name='profile_'+key;native[name]=[];donor[name]=[]
  for day,p in sorted(points.items()):
   values=sorted(profiles[day],key=lambda r:int(r['node']));assert len(values)==34
   native[name]+=p[key];donor[name]+=[float(r[column])for r in values]
  floors[name]=floor;units[name]=unit
 return native,donor,floors,units

def distance(key,a,b):
 assert len(a)==len(b)and a and all(math.isfinite(x)for x in a+b)
 return max(abs(x-y)/(max(1.,abs(x),abs(y))if key=='profile_head_cm'else 1.)for x,y in zip(a,b))

def instrument(source):
 begin=source.index('      subroutine soilwateroutput(task)');end=source.index('      end',source.index('      return',source.index("'Illegal value for Task'",begin)))+len('      end');part=source[begin:end]
 def change(a,b):
  nonlocal part
  assert part.count(a)==1,a;part=part.replace(a,b)
 change('      implicit none','      use MOD_grid, only: numnod,z,dz\n      use MOD_solute, only: hupsel_cml=>cml\n      use MOD_soiltemperature, only: tsoil\n      use variables, only: h,theta\n      implicit none')
 change('      integer, intent(in)  :: task','      integer, save :: hupsel_unit,hupsel_day\n      integer :: hupsel_node\n      integer, intent(in)  :: task')
 change('      case (1)','      case (1)\n         hupsel_day=0\n         open(newunit=hupsel_unit,file="hupsel_profiles.csv",status="replace")\n         write(hupsel_unit,"(a)")"day,node,z_cm,dz_cm,head_cm,water_content,temperature_c,concentration_mg_cm3"')
 change('      case (2)','      case (2)\n         hupsel_day=hupsel_day+1')
 change('      case (4)','      case (4)\n         close(hupsel_unit)')
 change('      return','      if(task==1.or.task==2)then\n         do hupsel_node=1,numnod\n            write(hupsel_unit,\'(i0,a,i0,6(a,es25.17e3))\')hupsel_day,\',\',hupsel_node, &\n             \',\',z(hupsel_node),\',\',dz(hupsel_node),\',\',h(hupsel_node),\',\',theta(hupsel_node), &\n             \',\',tsoil(hupsel_node),\',\',hupsel_cml(hupsel_node)\n         end do\n      end if\n      return')
 return source[:begin]+part+source[end:]

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve());daily,crop,points,old,accounting,swp=native_data();status=json.loads((ROOT/'integration/dataqual15_hupsel/STATUS.json').read_text())['sprint03'];report=dict(status='IN_PROGRESS',events=[],registration=status,accounting=accounting,physical_input_changes=False,production_changes=False,canonical_admitted=False);(out/'PREREGISTRATION.json').write_text(json.dumps(status,indent=2)+'\n',newline='\n')
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
 def run(cmd,label,cwd,expected=0,timeout=240):
  i=len(report['events']);start=time.monotonic()
  with(out/f'{i}.stdout').open('wb')as so,(out/f'{i}.stderr').open('wb')as se:
   try:r=subprocess.run(list(map(str,cmd)),cwd=cwd,stdout=so,stderr=se,timeout=timeout);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=code,censored=censored,seconds=time.monotonic()-start,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));save();assert code==expected and not censored,(label,out/f'{i}.stderr')
 report['source_sha256']={name:sha((ROOT/name).read_bytes())for name in ['tests/dataqual15_hupsel/scientific_followup.py','tests/dataqual15_hupsel/inspect_profiles.py','tests/dataqual15/original_sources.py']};save()
 provider=out/'original-O2';run([sys.executable,'-B',ROOT/'tests/dataqual15/original_sources.py','--output',provider,'--compiler',fc,'--optimization','O2'],'original-build',ROOT)
 original=(provider/'selected/swapoutput.f90').read_text();observer=instrument(original);source=out/'hupsel_output.f90';source.write_text(observer,newline='\n');(out/'OUTPUT_ONLY.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),observer.splitlines(True),fromfile='original/swapoutput.f90',tofile='output-only/swapoutput.f90')),newline='\n')
 flags=['-O2','-cpp','-Dlinux','-finit-local-zero','-fallow-argument-mismatch','-ffree-line-length-none','-I'+str(provider/'swobj'),'-I'+str(provider/'ttobj'),'-J'+str(provider/'swobj')];objects=[]
 for src,name in [(source,'output'),(provider/'selected/swap_main.f90','main')]:
  obj=out/(name+'.o');run([fc,*flags,'-c',src,'-o',obj],'compile-'+name,out);objects.append(obj)
 exe=out/'swap431';args=out/'link.args';args.write_text('\n'.join('"'+str(x)+'"'for x in [*objects,*[p for p in sorted((provider/'swobj').glob('*.o'))if p.name!='swapoutput.o'],provider/'ttobj/libttutil.a','-o',exe]),newline='\n');run([fc,'@'+str(args)],'link',out)
 report['original_executable_sha256']=sha(exe.read_bytes());series={};profiles={};registration=None;previous=None
 for cap in [.04,.02,.01,.005,.0025,.00125]:
  case=out/('dtmax-'+str(cap));case.mkdir()
  for name in ['maize.crp','potato.crp','grass.crp','283.met','swap.dra']:(case/name).write_bytes((ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'/name).read_bytes())
  raw=swp if cap==.04 else re.sub(rb'(?im)^(\s*DTMAX\s*=\s*)[\d.eE+\-]+',lambda m:m[1]+str(cap).encode(),swp);(case/'swap.swp').write_bytes(raw)
  run([exe],'reference-'+str(cap),case,expected=100);assert(case/'swap.ok').exists();scalar=rows((case/'result_output.csv').read_bytes());assert len(scalar)==1097
  if cap==.04:assert scalar==old,'immutable baseline scalar output changed'
  nodal=collections.defaultdict(list)
  for row in rows((case/'hupsel_profiles.csv').read_bytes()):nodal[int(row['day'])].append(row)
  assert sorted(nodal)==list(range(1097))and all(len(v)==34 for v in nodal.values())
  series[cap]=scalar;profiles[cap]=nodal
  if cap==.005:
   native,coarse,floors,units=features(series[.01],profiles[.01],daily,crop,points);_,fine,_,_=features(scalar,nodal,daily,crop,points)
   registration={key:dict(training_change=distance(key,coarse[key],fine[key]),floor=floors[key],limit=floors[key]if key in ['crop_dvs','crop_tsum','crop_pwrt','crop_pwlv','crop_pwst','crop_pwso','crop_rdpot','crop_potential_harvested_dry_matter']else 3*distance(key,coarse[key],fine[key])+floors[key],unit=units[key])for key in native};previous={key:v['training_change']for key,v in registration.items()};(out/'FROZEN_BOUNDS_BEFORE_HOLDOUT.json').write_text(json.dumps(registration,indent=2)+'\n',newline='\n');report['assessment']={};save()
  if cap<.005:
   native,ref,_,_=features(scalar,nodal,daily,crop,points);_,prior,_,_=features(series[cap*2],profiles[cap*2],daily,crop,points);fields={}
   for key,bound in registration.items():
    error=distance(key,native[key],ref[key]);change=distance(key,prior[key],ref[key]);fields[key]=dict(native_error=error,limit=bound['limit'],inside_frozen_bound=error<=bound['limit'],reference_change=change,previous_change=previous[key],reference_change_decreases=change<=previous[key]+bound['floor']);previous[key]=change
   report['assessment'][str(cap)]=fields;save()
 report.update(status='FULL1096_HUPSEL_SCIENTIFIC_MEASUREMENTS_COMPLETE',registered_gate_pass=all(v['inside_frozen_bound']and v['reference_change_decreases']for fields in report['assessment'].values()for v in fields.values()),frozen_bounds=registration,whole_energy_qualified=False);save();print(json.dumps(dict(status=report['status'],registered_gate_pass=report['registered_gate_pass'],accounting=accounting),indent=2))
if __name__=='__main__':main()
