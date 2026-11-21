"""Read original pressure initialization and literal qualified Frost/state science."""
import argparse,io,json,math,struct,subprocess,sys,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from initial_profile_frost_source_inverse import BASE,CORE,complete_inverse,blob,norm
from initial_pressure_profile_science import initialized_heads,PROVIDER
from analytical_hydraulic_archives import SHA
from experimental_project import switches
import frost_cde_drainage_model_forensics as explicit
import implicit_frost_model_forensics as implicit


def frost_history(raw,kind):
 """Read the actual original Snow1/heat1/SWHYST2 sequential state layout."""
 records=[];position=0
 while position<len(raw):
  length=struct.unpack_from('<i',raw,position)[0];assert 0<=length<=len(raw)-position-8
  assert struct.unpack_from('<i',raw,position+4+length)[0]==length
  records.append(raw[position+4:position+4+length]);position+=length+8
 values=iter(records)
 def take(format):return struct.unpack('<'+format,next(values))
 integer=lambda:take('i')[0]
 assert integer()==1 and integer()==0
 nodes=integer();assert nodes==34
 heads=take(str(nodes)+'d');pond=take('d')[0]
 assert integer()==1
 snow=take('d')[0],take('d')[0]
 evaporation=integer();assert evaporation in (0,1,2)
 for _ in range(evaporation):take('d')
 mode=integer();assert mode==2
 index=take(str(nodes)+'i');assert all(value in (-1,1) for value in index)
 arrays=[take(str(nodes)+'d') for _ in range(3)]
 assert integer()==1;temperatures=take(str(nodes)+'d')
 assert integer()==int(kind=='cde')
 assert all(math.isfinite(value) for value in (*heads,pond,*snow,*temperatures,*[value for row in arrays for value in row]))
 return dict(mode=mode,index=index,delp=arrays[0],fhyst=arrays[1],hm1=arrays[2],actual_Snow_state=snow)


def audit(profile,reference):
 complete_inverse();q=json.loads((profile/'RESULT.json').read_text());assert q['phase']=='short' and 'PASS_NOT_ADMITTED' in q['status'] and not subprocess.check_output(['git','diff',CORE,q['source'],'--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
 inputs=Path(q['input_root']);build=Path(q['build_root']);text=(inputs/'swap.swp').read_text(encoding='cp1252');selected=switches(text)
 assert selected['SWINCO']==selected['SWFROST']==selected['SWSNOW']==1 and selected['SWHYST']==2 and selected['SWKIMPL'] in (0,1)
 frozen=('tests/nomacro_drainage/frost_cde_drainage_model_forensics.py','tests/nomacro_drainage/implicit_frost_model_forensics.py','tests/nomacro_drainage/initial_pressure_profile_science.py','tests/nomacro_scheduled_subsurface/output_hysteresis_baseline.py')
 for path in frozen:assert norm((ROOT/path).read_bytes())==blob(BASE,path),'Changed original numerical/initialization/history reader'
 original=(ROOT/'reference/swap-4.3.1/source-archives/SWAP.ZIP').read_bytes()
 assert SHA(original)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
 with zipfile.ZipFile(io.BytesIO(original)) as archive:writer=archive.read('SWAP/swapoutput.f90')
 assert norm((reference/'build/swap-selected/swapoutput.f90').read_bytes())==norm(writer),'Changed complete original native writer layout'
 result=(implicit if selected['SWKIMPL'] else explicit).audit(profile,reference)
 for name,digest in PROVIDER.items():assert SHA(norm((reference/('build/swap-selected/'+name)).read_bytes()))==digest
 expected,initial=initialized_heads(text);lines=(profile/'trajectory/original/donor.stdout').read_text().splitlines();actual=next(list(map(float,line.split()[3:])) for line in lines if line.startswith('HYBRID_HYDRAULIC '));assert len(actual)==34 and actual==expected,'Original saturated-tail pressure initialization differs'
 checkpoints=[];scanning=False
 for path in (profile/'trajectory').glob('accepted-column-1-day-*.zip'):
  day=int(path.name.split('-')[-1].split('.')[0])
  with zipfile.ZipFile(io.BytesIO(path.read_bytes())) as z:
   native=z.read('macro.bin');observed=frost_history(z.read('result.end'),q['kind'])
  assert observed['mode']==2;scanning|=any(value!=-1 for value in observed['index']) or any(value!=1.0 for value in observed['fhyst'])
  expected_codec=('S5FIC002' if q['kind']=='cde' else 'S5FIW002') if selected['SWKIMPL'] else ('S5FDC001' if q['kind']=='cde' else 'S5FDW001')
  assert native[:8].decode()==expected_codec;checkpoints.append(dict(day=day,actual_native_codec=expected_codec,actual_history_mode=2))
 assert {row['day'] for row in checkpoints}=={2,4,19,23,30,34,35} and scanning
 result.update(status='INDEPENDENT_ORIGINAL_PRESSURE_FROST_FIXED_LIMITS_SATURATED_HEADS_HISTORY_NATIVE_EXACT_COLD_PASS',exact_initial_pressure_nodes=34,original_initial_profile=initial,actual_hysteresis_scanning_or_reversal=scanning,native_checkpoints=sorted(checkpoints,key=lambda row:row['day']),fresh_compiler_executions=0,fresh_model_executions=0,canonical_admission=False)
 return result


if __name__=='__main__':
 p=argparse.ArgumentParser()
 for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();q=audit(a.profile,a.reference_work)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],q['kind'],q['optimization'])
