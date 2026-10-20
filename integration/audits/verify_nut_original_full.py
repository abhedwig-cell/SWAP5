"""Qualify actual original full-caller evidence, never a production N admission."""
from pathlib import Path
import base64,csv,gzip,hashlib,io,json,math,re,runpy,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
BASE='790fb52f7fb22c2cba3a0fafe90341bf83238380'
STATUS='integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
KEY='original_full_caller_qualification_20261020'
OWNED={'integration/audits/run_nut_original_full.py','integration/audits/verify_nut_original_full.py'}
NAMES=['original-control-prefix','fallow-low','fallow-high','fallow-no-denitr','fallow-ample-no-denitr']
def require(ok,why):
 if not ok:raise ValueError(why)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())[KEY]
def helper():return runpy.run_path(str(ROOT/'tests/nut-crop/verify_historical_gross.py'),run_name='original_full_capsule_helpers')
def source():
 s=record();require(s['base_canonical']==BASE,'original caller baseline')
 require(set(s['postimages'])==OWNED,'original caller ownership')
 for p,h in s['postimages'].items():require(sha((ROOT/p).read_bytes())==h,'original caller postimage '+p)
 require(not git('status','--porcelain','--',*OWNED),'dirty original caller source')
 target=s.get('qualified_head','HEAD');git('merge-base','--is-ancestor',BASE,target)
 require(not git('diff',BASE,target,'--','src','tests','tools','reference','.github','app','examples'),'original caller changed production/scientific providers')
 return s

def csvbody(b):return '\n'.join(l for l in b.decode('cp1252').splitlines()if l and not l.startswith('*'))
def rows(b,header):
 lines=b.decode('cp1252').splitlines();starts=[i for i,l in enumerate(lines)if l.startswith(header)];require(len(starts)==1,'original output header')
 return list(csv.DictReader(lines[starts[0]:]))
STOCKS=['NFOM','NBio','NHum','NH4','NO3']
INS=['NFOM_add','NHum_add','NFOM_cres','NHum_cres','NH4N_amend','NO3N_amend','NH4N_cres','NO3N_cres','NH4_intop','NO3_intop','NH4_inlat','NO3_inlat','NH4_inbot','NO3_inbot']
OUTS=['NH3N_volat','NH4_upt','NO3_upt','NH4_out','NO3_out','NO3_denitr']
def balance(row):
 v={k:float(x)for k,x in row.items()if k!='Date'};require(all(math.isfinite(x)for x in v.values()),'nonfinite original N output')
 old=sum(v[k+'_old']for k in STOCKS);end=sum(v[k+'_end']for k in STOCKS);incoming=sum(v[k]for k in INS);outgoing=sum(v[k]for k in OUTS)
 residual=(old+incoming-outgoing-end)*1e-4;scale=max(abs(old)+abs(incoming),abs(end)+abs(outgoing),1e-30)*1e-4
 bound=0.
 for k in [s+'_old'for s in STOCKS]+[s+'_end'for s in STOCKS]+INS+OUTS:
  m=re.search(r'[Ee]([+-]?\d+)',row[k]);require(m is not None,'original printed scientific precision');bound+=.5*10.**(int(m[1])-4)*1e-4
 uptake=v['NH4_upt']+v['NO3_upt'];external_out=(outgoing-uptake)*1e-4;whole=(old+incoming-outgoing+uptake-end)*1e-4
 nh4=(v['NH4_old']+v['NH4N_amend']+v['NH4N_cres']+v['Nminer']+v['NH4_intop']+v['NH4_inlat']+v['NH4_inbot']-v['NH4_upt']-v['NH4_out']-v['NH4_nitrif']-v['NH4_end'])*1e-4
 no3=(v['NO3_old']+v['NO3N_amend']+v['NO3N_cres']+v['NO3_intop']+v['NO3_inlat']+v['NO3_inbot']+v['NH4_nitrif']-v['NO3_upt']-v['NO3_out']-v['NO3_denitr']-v['NO3_end'])*1e-4
 organic=(sum(v[k+'_old']-v[k+'_end']for k in ['NFOM','NBio','NHum'])+v['NFOM_add']+v['NFOM_cres']+v['NHum_add']+v['NHum_cres']-v['Nminer'])*1e-4
 require(abs(nh4+no3+organic-residual)<=1e-10,'original forms do not sum to total soil N')
 return dict(whole_n_residual_kg_m2=whole,whole_n_external_out_kg_m2=external_out,whole_n_abs_relative_residual=abs(whole)/scale,nh4_residual_kg_m2=nh4,no3_residual_kg_m2=no3,organic_residual_kg_m2=organic,date=row['Date'].strip(),initial_kg_m2=old*1e-4,input_kg_m2=incoming*1e-4,output_kg_m2=outgoing*1e-4,final_kg_m2=end*1e-4,residual_kg_m2=residual,abs_relative_residual=abs(residual)/scale,conservative_printed_rounding_bound_kg_m2=bound,top_carrier_mm=v['WFl_inTop'],nitrate_top_kg_ha=v['NO3_intop'],nitrate_end_kg_ha=v['NO3_end'],nitrate_vsmall_stock_kg_ha=v['WVol_end']*1e-11,abs_fallow_uptake_kg_m2=(abs(v['NH4_upt'])+abs(v['NO3_upt']))*1e-4)

def validate(f,reader=lambda p:(ROOT/p).read_bytes()):
 require(sha(base64.b64decode(reader('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64')))== '18396ecb9ec297e360d9ef720b8f5359522bca05070c6305c5d9608324247f4c','original archive identity')
 require(sha(base64.b64decode(reader('integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64')))== 'ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193','original TTUTIL identity')
 result=json.loads(f['actual/result.json']);require(result['status']=='ORIGINAL_FULL_MAIN_EXECUTED_QUALIFICATION_ONLY','original full experiment not completed')
 for p,h in result['input_sha256'].items():require(sha(reader(p))==h,'original executed input '+p)
 ev=json.loads(f['actual/events.json']);require(len(ev)==16,'original full build/native inventory')
 require(sum(e['category']=='original_native'for e in ev)==10,'original full native caller count')
 require(all(e['returncode']==(100 if e['category']=='original_native'else 0)for e in ev),'original full case/compile failure')
 for e in ev:
  for stream in ['stdout','stderr']:require(sha(f['actual/'+e[stream]])==e[stream+'_sha256'],'original event raw '+stream)
 sys.path.insert(0,str(ROOT/'tools/vq'));buildmod=runpy.run_path(str(ROOT/'tools/vq/b0_source_runner.py'),run_name='original_dec_selection');order=buildmod['SWAP_ORDER'];require(len(order)==63,'original63 source providers')
 exe=set();opt_events={}
 for opt in ['O0','O2']:
  prefix='actual/build-'+opt+'/';manifest=json.loads(f[prefix+'INPUTS.json']);flags=manifest['flags'];require('-'+opt in flags and '-finit-local-zero'in flags and '-fallow-argument-mismatch'in flags,'original GNU compatibility flags')
  if opt=='O0':require('-fcheck=all'in flags and '-ffpe-trap=invalid,zero,overflow'in flags,'original checked O0')
  for p,h in manifest['source_sha256'].items():require(sha(f[prefix+p])==h,'original raw source member '+p)
  for name in order:
   raw=f[prefix+'source/SWAP/'+name];expected=buildmod['select_dec_branches'](raw.decode('cp1252')).encode('cp1252');require(f[prefix+'selected/'+name]==expected,'original process replaced '+name)
  compiled=[Path(c[c.index('-c')+1]).name for c in manifest['commands']if '-c'in c and '/selected/'in c[c.index('-c')+1]]
  require(sorted(compiled)==sorted(n for n in order if n!='swap_main.f90'),'original62 process build closure')
  cc=[e for e in ev if e['category']=='main_compile'and '/build-'+opt+'/'in ' '.join(e['command'])];ll=[e for e in ev if e['category']=='main_link'and '/build-'+opt+'/'in ' '.join(e['command'])]
  require(len(cc)==len(ll)==1 and Path(cc[0]['command'][cc[0]['command'].index('-c')+1]).name=='swap_main.f90','original complete main compilation')
  c=ll[0]['command'];objects=[Path(x).name for x in c if x.endswith('.o')];require(sorted(objects)==sorted(Path(n).stem+'.o'for n in order),'original main linked test stub or lost source')
  exe.add(c[c.index('-o')+1]);opt_events[opt]=[e for e in ev if e['category']=='original_native'and '/build-'+opt+'/'in e['command'][0]];require(len(opt_events[opt])==5,'original native matrix per optimization')
 require(all(e['command'][0]in exe for e in ev if e['category']=='original_native'),'original native not linked full main')
 frozen='tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-result_output.csv.gz'
 require(sha(reader(frozen))==sha(subprocess.check_output(['git','show',BASE+':'+frozen],cwd=ROOT)),'original frozen historical output identity')
 control=gzip.decompress(reader(frozen));summary={};watermax=0.
 for opt in ['O0','O2']:
  prefix='actual/'+opt+'/';actual=f[prefix+'original-control-prefix/result_output.csv'];require(csvbody(control).startswith(csvbody(actual)),'original frozen Andelst prefix regression')
  for name in NAMES:
   rr=result['runs'][opt+'/'+name];path=prefix+name+'/';require(rr['success']and rr['swap_ok']and not rr['error']and rr['returncode']==100,'original successful process/marker/error gate')
   require(path+'swap.ok'in f and b'simulation succesfully terminated'in f[path+'swap.ok'] and b'Model version: Swap 4.3.1'in f[path+'swap.ok'],'missing/corrupt original successful completion marker')
   for p,h in rr['input_sha256'].items():require(sha(f[path+p])==h,'original model input changed '+p)
   require(csvbody(f[path+'result_output.csv'])==csvbody(f['actual/O0/'+name+'/result_output.csv']),'original water O0/O2 drift')
   if name=='original-control-prefix':continue
   require(rr['soil_n_executed']and len(rr['nutrient_rows'])==10,'hydraulic control misrepresented as nutrient execution')
   swp=f[path+'swap.swp'].decode('cp1252');require(re.search(r'(?im)^\s*SWCROP\s*=\s*1\b',swp)and re.search(r'(?im)^SWCROPSNM\s*=\s*1\b',swp)and '1998-01-15'in swp,'original configured-crop fallow gate')
   text=f[path+'nut-main.snm'].decode();fields={m[1]:float(m[2])for m in re.finditer(r'(?m)^(\w+)\s*=\s*([+\-0-9.eEdD]+)\s*$',text)}
   require(all(fields['FOM'+str(i)+'_t']==0 for i in range(1,9))and fields['Hum_t']==0 and fields['Bio_t']==1e-8,'original R1 organic confound')
   require(all(fields[k]==0 for k in ['cNH4N_top','cNH4N_lat','cNO3N_lat','cNH4N_seep','cNO3N_seep','RateConNitrif_ref'])and fields['cNO3N_top']==.005,'original boundary/read defect confound')
   require(fields['cNO3_t']==(.05 if name in ['fallow-high','fallow-ample-no-denitr']else 0.)and fields['RateConDenitr_ref']==(0 if 'no-denitr'in name else 50.),'original initial/rate matrix')
   require('2099-01-01 1 0. 0.'in text,'original zero future amendment identity')
   nut=f[path+'result_nut.csv'];require(csvbody(nut)==csvbody(f['actual/O0/'+name+'/result_nut.csv']),'original N O0/O2 drift')
   nn=rows(nut,'Date,Day,Dcum,');require(len(nn)==10,'missing original daily chemistry')
   bb=[balance(row)for row in nn]
   for row,b in zip(nn,bb):
    require(float(row['Ndemand'])==0 and b['abs_fallow_uptake_kg_m2']<=1e-10,'original fallow demand/uptake confound')
    require(abs(b['residual_kg_m2']-rr['nutrient_rows'][bb.index(b)]['residual_kg_m2'])<1e-15,'original reported/raw N mismatch')
   wr=rows(f[path+'result_output.csv'],'DATE,');watermax=max(watermax,max(abs(float(row['BALDEV']))for row in wr if row['DATE']>='1998-01-01'))
   defects=[b for b in bb if b['top_carrier_mm']<0 and b['nitrate_end_kg_ha']<=max(1e-28,1.0002*b['nitrate_vsmall_stock_kg_ha']) and b['whole_n_residual_kg_m2']<-max(1e-10,5*b['conservative_printed_rounding_bound_kg_m2'])]
   if name=='fallow-ample-no-denitr':require(not defects and all(abs(b['residual_kg_m2'])<=b['conservative_printed_rounding_bound_kg_m2']+1e-10 for b in bb),'original ample control not within printed precision')
   else:require(defects,'original depleted negative carrier counterexample not reached')
   worst=min(bb,key=lambda b:b['whole_n_residual_kg_m2']);cumulative=bb[0]['initial_kg_m2']+sum(b['input_kg_m2']-b['whole_n_external_out_kg_m2']for b in bb)-bb[-1]['final_kg_m2'];scale=max(abs(bb[0]['initial_kg_m2'])+sum(abs(b['input_kg_m2'])for b in bb),abs(bb[-1]['final_kg_m2'])+sum(abs(b['whole_n_external_out_kg_m2'])for b in bb),1e-30)
   summary[opt+'/'+name]={'worst_daily':worst,'cumulative_residual_kg_m2':cumulative,'cumulative_abs_relative_residual':abs(cumulative)/scale,'cumulative_printed_bound_kg_m2':sum(b['conservative_printed_rounding_bound_kg_m2']for b in bb),'actual_negative_depleted_days':len(defects)}
 require(all(summary['O0/'+n]==summary['O2/'+n]for n in NAMES[1:]),'original independent budget optimization mismatch')
 return dict(status='ORIGINAL_FULL_FALLOW_NEGATIVE_SOURCE_DEFECT_QUALIFIED',original_native_models=10,original_daily_N_steps=80,original_source_providers=63,original_frozen_control_prefix='exact O0/O2',water_max_abs_printed_baldev_cm=watermax,budgets=summary,production_capability_admitted=False,full_capability=False)

def verify():
 s=source();return validate(helper()['capsule'](s['evidence']))
def self_test():
 f=helper()['capsule'](record()['evidence']);validate(f);passed=[]
 def reject(name,fn,reader=lambda p:(ROOT/p).read_bytes()):
  ff=dict(f);fn(ff)
  try:validate(ff,reader)
  except(ValueError,KeyError,IndexError):passed.append(name);return
  raise AssertionError('accepted original full corruption '+name)
 for p in ['actual/build-O0/selected/management_soil.f90','actual/build-O2/selected/swap_main.f90','actual/O0/fallow-low/result_nut.csv','actual/O2/fallow-ample-no-denitr/result_nut.csv','actual/O0/original-control-prefix/result_output.csv','actual/O2/fallow-low/swap.ok','actual/O0/fallow-high/nut-main.snm']:
  reject(p,lambda ff,p=p:ff.__setitem__(p,b'corrupt'))
 reject('current original build helper drift',lambda ff:None,lambda p:(ROOT/p).read_bytes()+(b'!'if p=='tools/performance/build_swap431_perf01.py'else b''))
 def remove_native(ff):
  e=json.loads(ff['actual/events.json']);ff['actual/events.json']=json.dumps([v for v in e if v['category']!='original_native']).encode()
 reject('missing original native processes',remove_native)
 return {'count':len(passed),'original_full_negative_controls':passed}
if __name__=='__main__':print(json.dumps(self_test()if '--self-test'in sys.argv else verify(),indent=2))
