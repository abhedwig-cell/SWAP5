"""Bounded real executable outer-envelope controls, without predecessor override."""
import argparse,hashlib,json,os,shutil,struct,subprocess,zlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True);p.add_argument('--case',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();base=a.case.resolve();out=a.output.resolve();out.mkdir(exist_ok=False)
raw=(base/'checkpoint.bin').read_bytes()
assert raw[:8]==b'S5HR0003' and zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
clock=struct.unpack_from('=d',raw,8)[0];assert clock==1
env=os.environ.copy();env.pop('SWAP5_DIAG_PREDECESSOR',None)
results=[]
for kind in ('valid','crc','schema','nodes','clock_nan','truncated','extra'):
    folder=out/kind;folder.mkdir()
    for f in base.iterdir():
        if f.suffix.lower()in ('.swp','.crp','.met','.dra','.nml'):shutil.copyfile(f,folder/f.name)
    data=bytearray(raw)
    if kind=='crc':data[20]^=1
    if kind=='schema':data[:8]=b'S5HR9999'
    if kind=='nodes':struct.pack_into('=i',data,16,35)
    if kind=='clock_nan':struct.pack_into('=d',data,8,float('nan'))
    if kind=='truncated':data=data[:-11]
    if kind=='extra':data=data[:-4]+b'UNSUPPORTED'+data[-4:]
    if kind not in ('crc','truncated'):struct.pack_into('=I',data,len(data)-4,zlib.crc32(data[:-4]))
    checkpoint=folder/'test.bin';checkpoint.write_bytes(data)
    r=subprocess.run([str(a.exe.resolve()),'input.nml',str(checkpoint),'1','swap.swp','maize.crp'],cwd=folder,env=env,capture_output=True,timeout=10)
    (folder/'stdout').write_bytes(r.stdout);(folder/'stderr').write_bytes(r.stderr)
    reached=b'no requested windows remain'in r.stdout+r.stderr
    assert reached==(kind=='valid'),(kind,r.stdout,r.stderr)
    assert not(folder/'checkpoint.bin').exists()and not(folder/'budget.csv').exists()
    results.append(dict(case=kind,returncode=r.returncode,decoded=reached))
(out/'RESULT.json').write_text(json.dumps(dict(executable_sha256=hashlib.sha256(a.exe.read_bytes()).hexdigest(),cases=results),indent=2))
print('CANOPY_NATIVE_OUTER_CHECKPOINT_CONTROLS_PASS')
