"""Observe actual Hupsel trials; pair only accepted receipts, preserving native bytes."""
import argparse,csv,hashlib,io,json,re,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/dataqual15'))
from original_sources import build_original
sha=lambda b:hashlib.sha256(b).hexdigest()
def rows(raw):return list(csv.DictReader(io.StringIO(raw.decode())))

def generate(out):
 original=(ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
 anchor='          if(coupled%status/=MICRO_DW_OK)return'
 assert original.count(anchor)==1
 snippet=(ROOT/'tests/dataqual15_hupsel/uptake_observation.inc').read_text()
 (out/'observed_backend.f90').write_text(original.replace(anchor,anchor+'\n'+snippet),newline='\n')
 original=(ROOT/'app/solute_project/main.f90').read_text();anchor='      associate(s=>observation%accepted_water_flux_substeps(k))';assert original.count(anchor)==1
 snippet="""
        if(s%t0>=582d0.and.s%t0<585d0)then
          write(*,*)'UPTAKE_ACCEPTED',s%t0,s%t1,s%root_potential_cm_day,sum(s%root_sink), &
             s%root_drought_reduction_cm_day,s%root_oxygen_reduction_cm_day,s%root_salinity_reduction_cm_day
        end if
"""
 (out/'observed_main.f90').write_text(original.replace(anchor,anchor+snippet),newline='\n')
 recipe=ROOT/'tests/dataqual15_hupsel/build_and_run.py';raw=recipe.read_bytes()
 assert sha(raw)=='de9a619c832113cf4e1ebabde76aac0730aba22163b1efaa75bb95a6e3a95d93',('unreconciled sealed builder',sha(raw))
 source=raw.decode();anchor='order=[];seen=set();dependencies={}'
 assert source.count(anchor)==1
 source=source.replace(anchor,"mapping['mod_fmr_serialized_reference_backend']=Path("+repr(str(out/'observed_backend.f90'))+")\n"+anchor)
 # Preserve the recipe's own ROOT while selecting only the observed driver/backend.
 wrapper="from pathlib import Path\nsource="+repr(source)+"\nexec(compile(source,'sealed Hupsel recipe with explicit observer selection','exec'),{'__name__':'__main__','__file__':"+repr(str(recipe))+"})\n"
 (out/'builder.py').write_text(wrapper,newline='\n')

def select_accepted(out):
 accepted={}
 for line in (out/'native.stdout').read_text().splitlines():
  fields=line.split()
  if fields and fields[0]=='UPTAKE_ACCEPTED':
   v=list(map(float,fields[1:]));key=(round(v[0],12),round(v[1],12));assert key not in accepted;accepted[key]=v
 trials={};total=0
 with (out/'case/uptake-trials.dat').open()as f:
  while header:=f.readline():
   values=header.split();n=int(values[2]);lines=[header,*[next(f)for _ in range(3+n)]];total+=1
   key=(round(float(values[0]),12),round(float(values[1]),12))
   if key in accepted:trials[key]=lines
 assert set(trials)==set(accepted)and accepted
 selection=[]
 with (out/'accepted-inputs.dat').open('w',newline='\n')as stream:
  for key,v in sorted(accepted.items()):
   lines=trials[key];nodes=[list(map(float,line.split()))for line in lines[4:]]
   assert abs(sum(r[33]for r in nodes)-v[3])<1e-12,('accepted nodal sink mismatch',key)
   assert abs(float(lines[0].split()[4])-v[2])<1e-12
   stream.writelines(lines);selection.append(dict(t0=v[0],t1=v[1],demand=v[2],uptake=v[3],drought=v[4],oxygen=v[5],salinity=v[6]))
 for day in [583,584,585]:assert abs(sum(r['t1']-r['t0']for r in selection if int(r['t0'])==day-1)-1)<1e-10
 return dict(total_trial_records=total,accepted_cases=len(selection),accepted_intervals=selection,batch_sha256=sha((out/'accepted-inputs.dat').read_bytes()),rejected_and_sibling_records_retained=True)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);fc=str(a.compiler.resolve());record=dict(status='IN_PROGRESS',events=[],production_changed=False,no_checkpoint_rebinding=True)
 def save():(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',newline='\n')
 def run(cmd,label,cwd=out,timeout=240,expected=0):
  start=time.monotonic()
  with(out/(label+'.stdout')).open('wb')as so,(out/(label+'.stderr')).open('wb')as se:
   try:r=subprocess.run(list(map(str,cmd)),cwd=cwd,stdout=so,stderr=se,timeout=timeout);code=r.returncode;censored=False
   except subprocess.TimeoutExpired:code=None;censored=True
  record['events'].append(dict(label=label,command=list(map(str,cmd)),seconds=time.monotonic()-start,returncode=code,censored=censored));save();assert code==expected and not censored,(label,code)
 generate(out)
 run([sys.executable,'-B',ROOT/'tests/dataqual15/original_sources.py','--output',out/'original-O2','--compiler',fc,'--optimization','O2'],'original-build')
 run([sys.executable,'-B',out/'builder.py','--driver',out/'observed_main.f90','--output',out/'build','--compiler',fc,'--optimization','O2','--ttutil-archive',out/'original-O2/ttobj/libttutil.a'],'native-build',timeout=600)
 case=out/'case';case.mkdir()
 for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:(case/name).write_bytes((ROOT/'reference/swap-4.3.1/projects/1.hupselbrook'/name).read_bytes())
 reader=out/'build/read_fallow';run([reader,'swap.swp','283.met','swap.dra','1096'],'prepare',case)
 text=(case/'input.nml').read_text();assert text.count('&column ')==1;text=text.replace('&column ','&column original_hupsel_rotation=.true.,reactive_substep_chemistry=.true.,',1);(case/'input.nml').write_text(text,newline='\n')
 ends=[float(v)for v in re.search('^ends_day=(.*)$',text,re.M)[1].split(',')if v.strip()];stop=next(i+1 for i,v in enumerate(ends)if v==585)
 exe=out/'build/swap5_hupsel_germination';run([exe,'input.nml','-',stop,'swap.swp','maize.crp'],'native',case,timeout=1800)
 with tarfile.open(ROOT/'integration/dataqual15_hupsel/UNION_C3_HUPSEL_EVIDENCE.tar.xz')as t:
  for name in ['budget.csv','crop.csv']:
   golden=rows(t.extractfile('cases/hupsel-full1096/'+name).read());actual=rows((case/name).read_bytes());assert actual==golden[:len(actual)]and actual,(name,'observer changed trajectory')
  assert (case/'checkpoint.bin').read_bytes()[:8]==b'S5HR0003'
 record['selection']=select_accepted(out);record.update(status='ACTUAL_ACCEPTED_UPTAKE_INPUTS_CAPTURED',literal_585_day_budget_and_crop_exact=True,executable_sha256=sha(exe.read_bytes()),source_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes())for p in [Path(__file__),ROOT/'tests/dataqual15_hupsel/uptake_observation.inc',ROOT/'tests/dataqual15_hupsel/build_and_run.py']});save();print(json.dumps({k:v for k,v in record.items()if k not in ['selection','events']},indent=2))
if __name__=='__main__':main()
