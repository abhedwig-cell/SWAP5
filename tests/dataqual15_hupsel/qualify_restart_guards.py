"""Reject corrupted source-bound original joint Hupsel restart streams."""
import argparse,hashlib,json,shutil,struct,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--case',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();b=a.bundle.resolve();base=a.case.resolve();o=a.output.resolve();o.mkdir();build=json.loads((b/'BUILD.json').read_text());assert all(sha(Path(s))==h for s,h in build['source_sha256'].items());raw=(base/'checkpoint-250.bin').read_bytes();assert raw[:8]==b'S5HG0002';assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0];events=[]
for kind in ['crc','tag','source','clock_nan','root_negative','truncated','root_above_max','potential_root_above_max','dvs_nan','dvs_out_of_range','tsum_nan','tsum_negative','days_negative','days_future','clock_fractional','extra_payload']:
 f=o/kind;f.mkdir()
 for n in ['swap.swp','swap.dra','maize.crp','283.met','input.nml']:shutil.copyfile(base/n,f/n)
 data=bytearray(raw)
 if kind=='crc':data[20]^=1
 elif kind=='tag':data[:8]=b'INVALID!'
 elif kind=='source':data[8]^=1
 elif kind=='clock_nan':struct.pack_into('=d',data,12,float('nan'))
 elif kind=='root_negative':struct.pack_into('=d',data,68,-1.)
 elif kind=='truncated':data=data[:-11]
 elif kind=='root_above_max':struct.pack_into('=d',data,68,1000.)
 elif kind=='potential_root_above_max':struct.pack_into('=d',data,76,1000.)
 elif kind=='dvs_nan':struct.pack_into('=d',data,52,float('nan'))
 elif kind=='dvs_out_of_range':struct.pack_into('=d',data,52,2.1)
 elif kind=='tsum_nan':struct.pack_into('=d',data,60,float('nan'))
 elif kind=='tsum_negative':struct.pack_into('=d',data,60,-1.)
 elif kind=='days_negative':struct.pack_into('=i',data,48,-1)
 elif kind=='days_future':struct.pack_into('=i',data,48,251)
 elif kind=='clock_fractional':struct.pack_into('=d',data,12,250.5)
 elif kind=='extra_payload':data=data[:-4]+b'unsupported'+data[-4:]
 if kind not in ['crc','truncated']:struct.pack_into('=I',data,len(data)-4,zlib.crc32(data[:-4]))
 restart=f/'bad.bin';restart.write_bytes(data);cmd=[str(b/'swap5_hupsel_germination'),'input.nml',str(restart),'366','swap.swp','maize.crp'];t=time.monotonic();r=subprocess.run(cmd,cwd=f,capture_output=True,timeout=30);(f/'stdout').write_bytes(r.stdout);(f/'stderr').write_bytes(r.stderr);assert r.returncode!=0,kind;assert not(f/'budget.csv').exists()and not(f/'checkpoint.bin').exists(),kind
 events.append(dict(case=kind,returncode=r.returncode,seconds=time.monotonic()-t,command=cmd));print(kind,'PASS',flush=True)
assert (base/'checkpoint-250.bin').read_bytes()==raw
(o/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_HUPSEL_RESTART_STATE_AND_CORRUPTION_CONTROLS_PASS',events=events,source_sha256=build['source_sha256'],executable_sha256=sha(b/'swap5_hupsel_germination'),checkpoint_sha256=hashlib.sha256(raw).hexdigest()),indent=2)+'\n')
