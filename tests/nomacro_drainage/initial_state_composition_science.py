"""Independent original initialization/state, mass, native and cold observations."""
import argparse,io,json,math,re,struct,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_state_composition_source_inverse import BASE,CORE,SURFACES,git
from initial_pressure_profile_science import ledger_cold,initialized_heads,PROVIDER
from analytical_hydraulic_archives import SHA
from experimental_project import switches
from output_hysteresis_baseline import history


def initial_heads(text,selector):
 expected,details=initialized_heads(text)
 if selector==1:return expected,details
 assert selector==2
 table=re.search(r'(?mi)^[ \t]*ISUBLAY[ \t]+ISOILLAY[ \t]+HSUBLAY[ \t]+NCOMP[^\n]*\n((?:[ \t]*\d+[^\n]*\n)+)',text);assert table;z=[];last=None
 for line in table[1].splitlines():
  _,_,height,count=line.split();count=int(count);dz=float(height)/count
  for _ in range(count):z.append(-.5*dz if not z else z[-1]-.5*(last+dz));last=dz
 levels=re.findall(r'(?mi)^[ \t]*GWLI[ \t]*=[ \t]*([^!\r\n]+)',text);assert len(levels)==1;level=float(levels[0]);return [level-depth for depth in z],dict(original_hydrostatic_GWLI=level,HTB_ignored_by_original_selector2=True)


def audit(profile,reference,locations=None):
 q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_INITIAL_STATE_COMPOSITION_WATER_CDE_EXACT_COLD_PASS_NOT_ADMITTED' and q['days']==35
 assert not git('diff',CORE,q['source'],'--',*SURFACES)
 for path in ('tests/nomacro_drainage/initial_pressure_profile_science.py','tests/nomacro_scheduled_subsurface/output_hysteresis_baseline.py'):
  assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':'+path),'Unchanged independent parent reader changed'
 build=locations['build'] if locations else Path(q['build_root']);inputs=locations['inputs'] if locations else Path(q['input_root']);meta=json.loads((build/'BUILD.json').read_text());identity=meta['identity'];nodes=meta['project']['nodes'];text=(inputs/'swap.swp').read_text(encoding='cp1252');selected=switches(text);magic=q['native_codec'].encode();assert selected['SWINCO']==q['initial_selector']
 allowed=(b'S5IHW001',b'S5IHC001',b'S5IOW001',b'S5IOC001',b'S5HSW004',b'S5HSC004',b'S5IRW001',b'S5IRC003');assert magic in allowed
 for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
 for name,digest in identity['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
 for name,digest in identity['donor_objects'].items():assert SHA((reference/'build/swap-obj'/name).read_bytes())==digest
 for name,digest in PROVIDER.items():assert SHA((reference/('build/swap-selected/'+name)).read_bytes().replace(b'\r\n',b'\n'))==digest
 for field in ('donor_flags','kernel_flags'):assert '-'+q['optimization'] in identity[field]
 for role,digest in meta['executable_sha256'].items():
  files=[p for p in (build/('day_'+role),build/('day_'+role+'.exe')) if p.is_file()];assert len(files)==1 and SHA(files[0].read_bytes())==digest
 result=ledger_cold(magic)(profile,meta,dict(q,own=q['cold']),build)
 expected,initial=initial_heads(text,q['initial_selector']);lines=(profile/'trajectory/original/donor.stdout').read_text().splitlines();actual=next(list(map(float,line.split()[3:])) for line in lines if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==nodes and actual==expected,'Original initial pressures differ'
 rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()];samples=stocks=root_states=0;active_history=False
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   aux=z.read('macro.bin');end=z.read('result.end')
  assert aux[:8]==magic;samples+=1;offset=48
  if magic in (b'S5HSW004',b'S5HSC004'):
   vapor=identity['hydraulic_vapor'];domain=[4,nodes,vapor['numlay'],0,int(q['kind']=='cde'),0,0,1,0,0,1,2,1,6]+vapor['models']+[f if m>=8 else 0 for m,f in zip(vapor['models'],vapor['SWVAPOR'])];packed=struct.pack('<'+str(len(domain))+'i',*domain);assert aux[48:48+2*len(packed)]==packed+packed;offset+=2*len(packed)
  if q['kind']=='cde':
   saved=struct.unpack_from('<'+str(nodes+2)+'d',aux,offset);assert all(math.isfinite(v) and v>=0 for v in saved) and saved[-1]==rows[day-1]['solute_end_mg_cm2'];stocks+=1
  if magic in (b'S5IRW001',b'S5IRC003'):
   domain=[1,nodes,selected['SWSOLU'],1,selected['SWHYST'],selected['SWBOTB'],1,0];packed=struct.pack('<8i',*domain);assert aux[-96:-32]==packed+packed;values=struct.unpack('<4d',aux[-32:]);assert values[:2]==values[2:] and all(map(math.isfinite,values));root_states+=1
  if selected['SWHYST']:
   observed=history(end);assert observed['mode']==selected['SWHYST']
   active_history |= any(v!=(1 if selected['SWHYST']==1 else -1) for v in observed['index']) or any(v!=1.0 for v in observed['fhyst'])
 if selected['SWHYST']:assert active_history,'No actual hysteretic scanning/reversal observed'
 snow=dict(maximum_stock_cm=max(row['stock_end_cm'][2] for row in rows),snow_rain_cm=sum(row['external_flux_cm'][1] for row in rows),gross_snow_cm=sum(row['external_flux_cm'][2] for row in rows));assert snow==q['snow_observation']
 if selected['SWSNOW']:assert snow['maximum_stock_cm']>0,'Snow composition had no actual positive Snow stock'
 result.update(status='INDEPENDENT_ORIGINAL_INITIAL_STATE_COMPOSITION_PRESSURE_FIXED_MASS_NATIVE_HISTORY_EXACT_COLD_PASS',producer=q['source'],kind=q['kind'],optimization=q['optimization'],initial_selector=q['initial_selector'],exact_initial_pressure_nodes=nodes,initial_profile=initial,native_codec=magic.decode(),native_checkpoints=samples,exact_private_CDE_stocks=stocks,exact_root_diagnostic_witnesses=root_states,actual_hysteresis_reversal_or_scanning=bool(active_history),snow=snow,CDE_initial_stock=rows[0].get('solute_start_mg_cm2'),compiler_executions=0,model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['kind'],q['optimization'],q['initial_selector'])
