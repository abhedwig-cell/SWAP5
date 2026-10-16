"""CRC-correct native corruption must fail atomically in a fresh process."""
from pathlib import Path
import hashlib,json,os,struct,subprocess,time,zlib
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_THERMAL_RESTART_DIR']).resolve();OUT.mkdir(exist_ok=False)
COMPOSITION=Path(os.environ['N_THERMAL_COMPOSITION_DIR']).resolve()
results=[]
for opt in ['O0','O2']:
 b=COMPOSITION/opt;original=(b/'thermal-manual-restart.bin').read_bytes()
 grid=struct.pack('=4d',-2.5,-7.5,-15.,-25.)
 assert original[:8]==b'S5NC0004'and original.count(grid)==1
 p=original.index(grid);certificate=p-20
 cases={
  'crc':(len(original)-1,bytes([original[-1]^0x80])),
  'tag':(0,b'S5NC9999'),
  'parameter_id':(certificate,struct.pack('=q',999999)),
  'node_count':(certificate+8,struct.pack('=i',3)),
  'heat_disabled':(certificate+12,struct.pack('=i',0)),
  'invalid_certificate':(certificate+16,struct.pack('=i',0)),
  'equal_size_changed_grid':(p,struct.pack('=d',-2.6)),
  'changed_dz':(p+32,struct.pack('=d',5.1)),
  'nan_grid':(p,struct.pack('=d',float('nan'))),
  'nan_temperature':(p+64,struct.pack('=d',float('nan'))),
  'infinite_temperature':(p+64,struct.pack('=d',float('inf')))
 }
 for name,(offset,value)in cases.items():
  raw=bytearray(original);raw[offset:offset+len(value)]=value
  if name!='crc':raw[-4:]=struct.pack('=I',zlib.crc32(raw[:-4]))
  path=OUT/(opt+'-'+name+'.bin');path.write_bytes(raw)
  begin=time.perf_counter();r=subprocess.run([str(b/'test_thermal_joint'),'reject',str(path),str(OUT/'unused'),'manual'],capture_output=True,cwd=b)
  prefix=OUT/(opt+'-'+name)
  prefix.with_suffix('.stdout').write_bytes(r.stdout);prefix.with_suffix('.stderr').write_bytes(r.stderr)
  results.append(dict(opt=opt,case=name,seconds=time.perf_counter()-begin,returncode=r.returncode,input_sha256=hashlib.sha256(raw).hexdigest(),stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()))
  (OUT/'results.json').write_text(json.dumps(dict(status='RUNNING',results=results),indent=2)+'\n')
  assert r.returncode==0 and b'CROP_SOIL_INVALID_DISK=PASS'in r.stdout,(opt,name,r.stdout,r.stderr)
(OUT/'results.json').write_text(json.dumps(dict(status='PASS',cases=len(results),results=results),indent=2)+'\n')
print(json.dumps(dict(status='PASS',cases=len(results))))
