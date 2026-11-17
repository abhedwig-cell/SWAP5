"""Bounded actual original TimeControl event-closure qualification; no model run."""
import argparse, hashlib, json, subprocess, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-work', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    ref, out = args.reference_work.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((HERE/'manifest.json').read_text())
    prepared = json.loads((ref/'PREPARED.json').read_text())
    source = ref/'build/swap-selected/timecontrol.f90'
    assert sha(source) == manifest['original_sha256'] == prepared['provider_files']['build/swap-selected/timecontrol.f90']
    objects, tt = ref/'build/swap-obj', ref/'build/ttutil-obj'
    driver = HERE/'test_time_event.f90'
    report = dict(status='INCOMPLETE', source_manifest=manifest,
                  provider_manifest_sha256=sha(ref/'PREPARED.json'),
                  driver_sha256=sha(driver), recipe_sha256=sha(Path(__file__)),
                  compiler=subprocess.check_output(['gfortran','--version'],text=True),
                  linked_objects={p.name:sha(p) for p in objects.glob('*.o') if p.name not in ('swap_main.o','timecontrol.o')},
                  ttutil_sha256=sha(tt/'libttutil.a'), profiles={})
    for opt in ('O0','O2'):
        for kind in ('original','corrected'):
            target = out/(opt+'-'+kind)
            target.mkdir()
            body = source.read_bytes()
            anchor = b'      if (dt > dtevent) then'
            assert body.count(anchor) == 1
            if kind == 'corrected': body = body.replace(anchor,b'      if (dt+dtCrit > dtevent) then')
            generated = target/'timecontrol.f90'
            generated.write_bytes(body)
            assert sha(generated) == manifest['original_sha256' if kind=='original' else 'corrected_sha256']
            flags = ['-'+opt,'-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none',
                     '-fallow-argument-mismatch','-fcheck=all','-ffpe-trap=invalid,zero,overflow',
                     '-ffp-contract=off','-march=x86-64','-mtune=generic','-I',str(objects),'-I',str(tt)]
            exe = target/'time_event.exe'
            commands = [['gfortran',*flags,'-c',str(generated),str(driver)],
                        ['gfortran','-o',str(exe),*[str(p) for p in sorted(objects.glob('*.o')) if p.name not in ('swap_main.o','timecontrol.o')],
                         str(target/'timecontrol.o'),str(target/'test_time_event.o'),str(tt/'libttutil.a')], [str(exe)]]
            records = []
            for command in commands:
                started = time.perf_counter()
                result = subprocess.run(command,cwd=target,capture_output=True,text=True,timeout=90)
                records.append(dict(command=command,returncode=result.returncode,stdout=result.stdout,stderr=result.stderr,seconds=time.perf_counter()-started))
                (target/'commands.json').write_text(json.dumps(records,indent=2)+'\n')
                assert result.returncode == 0,result.stderr
            lines = [line for line in result.stdout.splitlines() if line.startswith('EVENT')]
            assert len(lines)==5
            values = [[float(v) for v in line.split()[1:]] for line in lines]
            if kind == 'corrected': assert all(row[3]==1.0 and row[4]==0.0 for row in values)
            else: assert values[0][4]==-4.0436209935990064e-11 and values[4][4]<-2e-10
            report['profiles'][opt+'-'+kind] = dict(records=records,values=values,source_sha256=sha(generated),executable_sha256=sha(exe))
            (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
        before,after = [report['profiles'][opt+'-'+k]['values'] for k in ('original','corrected')]
        assert before[1:4] == after[1:4]
    for kind in ('original','corrected'): assert report['profiles']['O0-'+kind]['values']==report['profiles']['O2-'+kind]['values']
    report.update(status='ACTUAL_ORIGINAL_CORRECTED_TIMECONTROL_COMPONENT_O0_O2_PASS',
                  expected_difference='Two near-event deficits close exactly; three ordinary/exact/overshoot controls remain identical.',
                  scope='Complete original TimeControl native closure; no model, macro, full scientific or global B1 qualification.')
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(report['status'])


if __name__ == '__main__': main()
