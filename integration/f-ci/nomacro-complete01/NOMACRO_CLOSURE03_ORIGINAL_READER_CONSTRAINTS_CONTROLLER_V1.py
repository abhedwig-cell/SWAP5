from pathlib import Path
import zipfile,io,subprocess,hashlib,json
R=Path('C:/Users/Veldh012/swap5-nomacro-scheduled-chemical01');E=Path('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600/evidence');base='9af88c3de6198ddec40c2674dd1542a89fa9c0d7';path='reference/swap-4.3.1/source-archives/SWAP.ZIP';raw=subprocess.check_output(['git','show',base+':'+path],cwd=R);sha=lambda b:hashlib.sha256(b).hexdigest();assert sha(raw)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
result=dict(status='ORIGINAL_READER_EXECUTION_CONSTRAINTS_SOURCE_OBSERVATION_NOT_EXHAUSTIVE_RELEASE_REVIEW',actual_canonical=base,archive_path=path,archive_sha256=sha(raw),members={},compiler_executions=0,model_executions=0,global_functional_inventory_complete=False)
with zipfile.ZipFile(io.BytesIO(raw)) as z:
 for name in ['SWAP/readswap.f90','SWAP/headcalc.f90','SWAP/boundbottom.f90','SWAP/MOD_Kavg_Szym.f90']:
  value=z.read(name);lines=value.decode('cp1252').splitlines();snippets=[]
  patterns=['Combination of hysteresis','Combination of tabulated','Combination of output coarse','Combination of macro-pore','swkmean == 7','SWBOTB = 6','SWBOTB = 7','swbotb.eq.6','swbotb.eq.7','Kavg_table','Kavg.tab','KavgTable']
  for index,line in enumerate(lines):
   if any(p.lower() in line.lower() for p in patterns):snippets.append(dict(first_line=max(1,index-2),lines=lines[max(0,index-3):min(len(lines),index+4)]))
  result['members'][name]=dict(bytes=len(value),sha256=sha(value),snippets=snippets)
reader=z if False else result['members']['SWAP/readswap.f90']
result['proven_not_historically_supported']=[dict(condition='any(iHWCKmodel(1:numlay)>1) AND SWHYST>=1',classification='NOT_HISTORICALLY_SUPPORTED',proof='SWAP/readswap.f90:1171-1172',scope='Original reader refuses non1 analytical or mixed hydraulic models with hysteresis; do not invent missing coupling'),dict(condition='any(iHWCKmodel(1:numlay)>1) AND SWSOPHY==1',classification='NOT_HISTORICALLY_SUPPORTED',proof='SWAP/readswap.f90:1171-1173'),dict(condition='SWKMEAN==7 AND SWKIMPL==1',classification='NOT_HISTORICALLY_SUPPORTED',proof='SWAP/readswap.f90:782-786')]
result['not_inferred']=['No proof that SWKMEAN7 is unsupported with explicit conductivity','Absence of a prohibition does not independently prove successful original implicit analytical execution','No claim that every Frost or thermal boundary combination is historically valid','No whole-family closure claim from finite representative tests']
with (E/'NOMACRO_CLOSURE03_ORIGINAL_READER_CONSTRAINTS_V1.json').open('x') as f:json.dump(result,f,indent=2);f.write('\n')
print(result['status'],len(result['proven_not_historically_supported']),flush=True)
