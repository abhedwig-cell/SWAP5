"""Incumbent37 real owner refusals on actual S5HR0004 streams, no state conversion."""
import argparse, hashlib, json, math, os, shutil, struct, subprocess, sys
from pathlib import Path
import qualify_rotation_restart_guards as legacy

ROOT = Path(__file__).resolve().parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def locations4(raw):
    # Same unchanged inner native layouts as the incumbent locator. Only the
    # owning app tag and its16-byte diagnostic trailer differ. Never rewrite
    # checkpoint bytes to make them look like an older supported schema.
    assert raw[:8] == b'S5HR0004' and legacy.crc(raw, 0, len(raw))
    clock, nodes = struct.unpack_from('=di', raw, 8); assert nodes == 34 and clock == int(clock)
    off = 20; inputs = []
    for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
        n = struct.unpack_from('=i',raw,off)[0]; assert 0 < n < 16777216
        inputs.append((name,off+4,n)); off += 4+n
    n = struct.unpack_from('=i',raw,off)[0]; maize = off+4; maize_end = maize+n
    assert raw[maize:maize+8] == b'S5HG0002' and legacy.crc(raw,maize,maize_end)
    assert struct.unpack_from('=d',raw,maize+12)[0] == clock
    n = struct.unpack_from('=i',raw,maize+84)[0]; physical = maize+88; physical_end = physical+n
    assert physical_end+4 == maize_end and raw[physical:physical+8] == b'S5PT0004'
    assert legacy.crc(raw,physical,physical_end)
    header = struct.unpack_from('=8siqii11qi2qdiiiqi',raw,physical)
    n,count = header[-4],header[-1]; assert n == 34 and 0 < count < 100000 and header[-6] == clock
    black = physical+168+8*count+3*8*n+16; micro = black+8; rutter = black+20
    assert struct.unpack_from('=i',raw,micro)[0] in (0,1)
    assert struct.unpack_from('=i',raw,rutter)[0] == 2
    assert struct.unpack_from('=d',raw,rutter+48)[0] == clock
    flag = len(raw)-136; management = flag+4; irrigation = len(raw)-88
    assert struct.unpack_from('=i',raw,flag)[0] == 1
    state = struct.unpack_from('=7i2d',raw,management)
    assert state[0] >= 1 and state[1] >= 1 and min(state[2:7]) >= 0
    assert struct.unpack_from('=d',raw,irrigation+4)[0] == clock
    assert all(math.isfinite(v) for v in struct.unpack_from('=2d',raw,len(raw)-20))
    return dict(clock=clock,inputs=inputs,maize=maize,maize_end=maize_end,physical=physical,
                physical_end=physical_end,black=black,micro=micro,rutter=rutter,
                grass_flag=flag,grass=management,irrigation=irrigation,grass_state=state)


def qualify(bundle, case, checkpoint, output):
    # Reuse the unmodified real corruption runner and every existing outcome
    # requirement. The new read-only locator describes the actual new stream.
    original = legacy.locations; argv = sys.argv[:]
    try:
        legacy.locations = locations4
        sys.argv = ['qualify_rotation_restart_guards.py','--bundle',str(bundle),
                    '--case',str(case),'--checkpoint',str(checkpoint),'--output',str(output)]
        legacy.main()
    finally: legacy.locations = original; sys.argv = argv
    r = json.loads((output/'RESULT.json').read_text())
    assert len(r['events']) == 37 and all(e['status'] == 'PASS' and e['returncode'] == 1 for e in r['events'])
    r['schema'] = 'S5HR0004'; r['legacy_schema_coercion'] = False
    (output/'S5HR4_RESULT.json').write_text(json.dumps(r,indent=2)+'\n')


def windows_bundle(build, out):
    r = json.loads((build/'BUILD.json').read_text()); b = r['baseline'].copy(); out.mkdir()
    exe = build/'default-diagnostic.exe'; assert sha(exe) == r['executable_sha256']
    source = build/'hupsel_rotation_restart.f90'; assert sha(source) == r['source_sha256']
    assert hashlib.sha256((ROOT/'app/solute_project/hupsel_rotation_restart.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest() == sha(source)
    sources = {}
    for name,digest in b['source_sha256'].items():
        if Path(name) == ROOT/'app/solute_project/hupsel_rotation_restart.f90': sources[str(source)] = sha(source)
        else: assert sha(Path(name)) == digest; sources[name] = digest
    b.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
             source_sha256=sources,executable_sha256=sha(exe))
    shutil.copyfile(exe,out/'swap5_hupsel_germination.exe')
    (out/'BUILD.json').write_text(json.dumps(b,indent=2)+'\n')
    return out


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('build','case','checkpoint','output'): p.add_argument('--'+name,type=Path,required=True)
    a = p.parse_args(); out = a.output.resolve()
    bundle = windows_bundle(a.build.resolve(),out.with_name(out.name+'-bundle')) if os.name == 'nt' else a.build.resolve()
    qualify(bundle,a.case.resolve(),a.checkpoint.resolve(),out)
