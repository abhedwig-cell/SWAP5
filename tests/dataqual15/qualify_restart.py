"""Use original captures to check the new codec and every new continuation guard."""
import argparse,csv,hashlib,json,shutil,struct,subprocess,time,zlib
from pathlib import Path
from checkpoint_layout import layout,payload
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--checkpoint',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();base=a.bundle.resolve();out=a.output.resolve();out.mkdir();build=json.loads((base/'BUILD.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();exe=base/'swap5_grass_startup';assert sha(exe)==build['executable_sha256'];exe.chmod(exe.stat().st_mode|0o100);assert all(sha(Path(s))==h for s,h in build['source_sha256'].items())
original=a.checkpoint.read_bytes();d=layout(original);events=[]
for kind in ['crc','truncated','layout','clock','source','roots','delay','potential_delay','cut_index','yield_nan','compatibility_nan']:
 b=bytearray(original);folder=out/kind;folder.mkdir()
 for n,h in build['original_inputs_sha256'].items():
  q=base/'original-interval'/n;assert sha(q)==h;shutil.copyfile(q,folder/n)
 shutil.copyfile(base/'original-interval/application.binding',folder/'application.binding')
 if kind=='crc':b[d['header']+16]^=1
 elif kind=='truncated':b=b[:-7]
 elif kind=='layout':struct.pack_into('=i',b,d['header'],112)
 elif kind=='clock':struct.pack_into('=d',b,d['header']+4,d['clock']+.5)
 elif kind=='source':(folder/'input.swp').write_bytes(b'* source rejection\n'+(folder/'input.swp').read_bytes())
 elif kind=='roots':struct.pack_into('=d',b,d['roots']+8,1000.)
 elif kind=='delay':
  at=d['actual']['start']+164+24*d['actual']['leaves']-4;struct.pack_into('=i',b,at,-1)
 elif kind=='potential_delay':struct.pack_into('=i',b,d['management'],-1)
 elif kind=='cut_index':struct.pack_into('=i',b,d['management']+20,0)
 elif kind=='yield_nan':struct.pack_into('=d',b,d['management']+4,float('nan'))
 elif kind=='compatibility_nan':
  flags=[q for q in d['compatibility']if struct.unpack_from('=i',b,q)[0]];assert flags,'select LAIEXP>=6 original checkpoint';struct.pack_into('=d',b,flags[-1]+4,float('nan'))
 if kind not in ['crc','truncated']:struct.pack_into('=I',b,len(b)-4,zlib.crc32(b[:-4]))
 restart=folder/'bad.bin';restart.write_bytes(b);cmd=[str(exe),str(int(d['clock'])+1),'retain-step','100000',str(restart)];t=time.monotonic()
 r=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=30);(folder/'stdout').write_bytes(r.stdout);(folder/'stderr').write_bytes(r.stderr)
 assert r.returncode!=0 and b'bound grass prefix restart rejected'in r.stdout,kind
 assert not(folder/'checkpoint.bin').exists()and not(folder/'budget.csv').exists(),kind
 events.append(dict(case=kind,returncode=r.returncode,seconds=time.monotonic()-t,command=cmd));print(kind,'REJECT_PASS',flush=True)
assert a.checkpoint.read_bytes()==original
(out/'RESULT.json').write_text(json.dumps(dict(status='SOURCE_BOUND_CODEC_V3_REJECTIONS_PASS',events=events,checkpoint_sha256=sha(a.checkpoint),source_sha256=build['source_sha256'],executable_sha256=sha(exe)),indent=2)+'\n')
