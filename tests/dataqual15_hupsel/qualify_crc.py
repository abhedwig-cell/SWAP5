"""Link the actual joint-restart CRC owner against measured providers; compare zlib."""
import argparse,json,pathlib,subprocess,zlib,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--build',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True)
a=p.parse_args();b=a.build.resolve();out=a.output.resolve();out.mkdir(exist_ok=False)
events=json.loads((b/'EVENTS.json').read_text())
compile=next(e['command'] for e in events if e['label']=='compile' and any(str(v).endswith('mod_age_joint_restart_file.f90')for v in e['command']))
main=next(e['command'][-1] for e in events if e['label']=='compile' and any(str(v).endswith('main.f90')for v in e['command']))
link=[v for v in next(e['command'] for e in events if e['label']=='link') if v!=main]
results=[]
fixtures=[b'',b'123456789',bytes(range(256))*300,
          (ROOT/'reference/swap-4.3.1/projects/1.hupselbrook/swap.swp').read_bytes()]
for opt in ('O0','O2'):
    obj=out/(opt+'.o')
    cmd=[('-'+opt if v in ('-O0','-O2') else '-J'+str(out) if v.startswith('-J') else v)for v in compile]
    cmd[cmd.index('-o')+1]=str(obj)
    subprocess.run(cmd,cwd=b,check=True,timeout=60)
    exe=out/(opt+'.exe')
    cmd=[str(obj) if v==compile[-1] else v for v in link];cmd[cmd.index('-o')+1]=str(exe)
    cmd[1:1]=['-I'+str(b),'-J'+str(out),str(ROOT/'tests/dataqual15_hupsel/crc_driver.f90')]
    subprocess.run(cmd,cwd=b,check=True,timeout=60)
    for i,raw in enumerate(fixtures):
        f=out/str(i);f.write_bytes(raw)
        r=subprocess.run([str(exe),str(f)],capture_output=True,check=True,timeout=5)
        actual=int(r.stdout.strip(),16);assert actual==zlib.crc32(raw)
        results.append(dict(opt=opt,fixture=i,bytes=len(raw),crc=actual))
(out/'RESULT.json').write_text(json.dumps(dict(results=results,source_sha256=hashlib.sha256((ROOT/'src/adapter/mod_age_joint_restart_file.f90').read_bytes()).hexdigest()),indent=2))
print('REAL_JOINT_CRC_ZLIB_O0_O2_PASS')
