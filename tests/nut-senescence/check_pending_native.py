#!/usr/bin/env python3
"""Discriminating pending-chemistry rejection with audited same-session native reuse."""
from pathlib import Path
import hashlib,json,os,struct,subprocess,time,zlib
root=Path(__file__).resolve().parents[2];parent=Path(os.environ['SENESCENCE_PRIMARY_DIR']).resolve();out=Path(os.environ['SENESCENCE_PENDING_PROBE_DIR']).resolve();out.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
primary=json.loads((parent/'result.json').read_text());assert primary['status']=='PASS'
assert primary['source_tree']==subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=root,text=True).strip()
for p,h in primary['input_sha256'].items():assert sha(root/p)==h,p
result={'primary_result_sha256':sha(parent/'result.json'),'source_tree':primary['source_tree'],'new_native_execution':True,'provider_compile_reused':True,'compiler':primary['compiler'],'input_sha256':{str(Path(__file__).relative_to(root)):sha(Path(__file__))},'runs':{}}
for opt in ['O0','O2']:
 b=parent/opt;exe=b/'test_senescence_joint';before=sha(exe);raw=bytearray((b/'senescence-restart.bin').read_bytes());assert raw[:8]==b'S5NC0002'
 pos=len(raw)-84;dm=struct.unpack_from('<3d',raw,pos+8);n=struct.unpack_from('<3d',raw,pos+32)
 # Keep the total within the actual crop-loss ledger. Root N/DM exceeds the
 # source eight-pool upper fraction while remaining finite and <=dry matter.
 bad=raw.copy();struct.pack_into('<d',bad,pos+32,dm[0]*.09);struct.pack_into('<d',bad,pos+40,n[1]*.5)
 assert dm[0]*.09+n[1]*.5+n[2]<=sum(n)
 struct.pack_into('<I',bad,len(bad)-4,zlib.crc32(bad[:-4]));path=out/(opt+'-invalid-source-mixture.bin');path.write_bytes(bad)
 t=time.perf_counter();p=subprocess.run([str(exe),'reject',str(path)],cwd=b,capture_output=True);elapsed=time.perf_counter()-t
 (out/(opt+'.stdout')).write_bytes(p.stdout);(out/(opt+'.stderr')).write_bytes(p.stderr)
 assert p.returncode==0 and b'INVALID_DISK=PASS'in p.stdout
 assert sha(exe)==before
 result['runs'][opt]={'returncode':p.returncode,'seconds':elapsed,'executable_sha256_before':before,'executable_sha256_after':sha(exe),'original_payload_sha256':sha(b/'senescence-restart.bin'),'mutant_sha256':sha(path),'stdout_sha256':sha(out/(opt+'.stdout')),'stderr_sha256':sha(out/(opt+'.stderr'))}
result['status']='PASS';(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
