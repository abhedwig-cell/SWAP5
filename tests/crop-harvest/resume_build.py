"""Recover only successful compiler work preceding one failed provider compile.

No native result may be inherited. Bind exact generated controller, commands,
source pin/current bytes, flags, compiler identity and live build artifacts.
Retain the failed attempt separately before any indexed log is replaced.
"""
from pathlib import Path
import hashlib,json,shutil,subprocess

def recover(root,out,controller,pin):
    sha=lambda b:hashlib.sha256(b).hexdigest()
    old=(out/'executed_runner.py').read_text();assert old==controller,'controller changed beyond recovery'
    events=json.loads((out/'events.json').read_text())
    assert events and events[-1]['category']=='compile' and events[-1]['returncode']!=0
    prefix=events[:-1]
    assert all(e['category']=='compile' and e['returncode']==0 for e in prefix),'native inheritance forbidden'
    failed=out/'failed-provider-build';failed.mkdir(exist_ok=False)
    shutil.copyfile(out/'events.json',failed/'events.json');shutil.copyfile(out/'executed_runner.py',failed/'executed_runner.py')
    bindings={}
    for e in events:
        for stream in ['stdout','stderr']:
            p=out/e[stream+'_file'];assert sha(p.read_bytes())==e[stream+'_sha256']
            shutil.copyfile(p,failed/p.name)
    for e in prefix:
        cmd=e['command'];source=Path(cmd[cmd.index('-c')+1]);obj=Path(cmd[cmd.index('-o')+1])
        assert obj.is_file()
        if source.is_relative_to(root):
            rel=str(source.relative_to(root))
            assert source.read_bytes()==subprocess.check_output(['git','show',pin+':'+rel],cwd=root),rel
        bindings[str(source)]=sha(source.read_bytes());bindings[str(obj)]=sha(obj.read_bytes())
    for q in (out/'O0').glob('*.mod'):bindings[str(q)]=sha(q.read_bytes())
    (out/'BUILD_RECOVERY.json').write_text(json.dumps(dict(scope='Compiler-only successful prefix reuse; zero native inheritance',source_pin=pin,
        original_controller_sha256=sha(old.encode()),original_events_sha256=sha((failed/'events.json').read_bytes()),bindings=bindings,
        reused_compile_events=len(prefix)),indent=2)+'\n')
    (out/'compiler_prefix.json').write_text(json.dumps(prefix,indent=2)+'\n')
    controller=controller.replace("FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={};", "FC=shlex.split(os.environ.get('FC','gfortran'));events=json.loads((OUT/'compiler_prefix.json').read_text());reuse_compile=list(events);inputs={};")
    needle=" args=list(map(str,args))\n"
    assert controller.count(needle)==1
    controller=controller.replace(needle,needle+''' if reuse_compile:
  event=reuse_compile.pop(0)
  assert category=='compile' and args==event['command'],'unexpected compile recovery command'
  return (OUT/event['stdout_file']).read_text()
''')
    # The resumed successful result keeps original prefix cost once. Its failed
    # terminal compile/cost and all raw output stay in failed-provider-build.
    return controller
