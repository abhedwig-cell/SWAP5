"""Execute the current real native reader against malformed nonmacro clock state."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import sys
import threading

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True);p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);p.add_argument('--project',choices=['saltfarm','grass'],required=True)
a=p.parse_args();a.output.mkdir();project={'saltfarm':h.SALTFARM,'grass':h.GRASSGROWTH}[a.project]
meta,case=validate_bundle(a.bundle,a.reference,project)
control=a.bundle/('full' if a.project=='saltfarm' else 'continuous')
origin=a.output/'proper';receipt=h.verify_checkpoint(control/'accepted-column-1-day-2.zip',2,meta['binding'],origin)
payload=(origin/'macro.bin').read_bytes()
assert payload[:8]==(b'S5HUP012' if project.solute else b'S5NON006')
workers=[];actual=h.start_process
def track(*args,**kwargs):
    process,log=actual(*args,**kwargs);workers.append(process);return process,log
def stop():
    for process in workers:
        if process.poll() is None:process.kill()
h.start_process=track;timer=threading.Timer(20,stop);timer.start();results=[]
try:
    for defect in ['nonfinite-season','invalid-year','old-codec','truncated-season']:
        bad=a.output/(defect+'-origin');shutil.copytree(origin,bad);data=bytearray(payload)
        if defect=='nonfinite-season':struct.pack_into('=d',data,36,float('nan'))
        elif defect=='invalid-year':struct.pack_into('=i',data,44,0)
        elif defect=='old-codec':data[:8]=b'S5HUP010' if project.solute else b'S5NON004'
        else:data=data[:36]
        (bad/'macro.bin').write_bytes(data);out=a.output/defect;out.mkdir()
        try:h.run(h.executable(a.bundle,'day_donor'),h.executable(a.bundle,'day_kernel'),case,out,3,
            checkpoint_day=2,origin=bad,origin_receipt=receipt,runtime=True,project=project)
        except RuntimeError:pass
        else:raise AssertionError('Malformed seasonal state accepted: '+defect)
        stderr=(out/'original/donor.stderr').read_text()
        expected={'nonfinite-season':'Nonfinite nonmacro seasonal clock','invalid-year':'Invalid nonmacro calendar year',
            'old-codec':'Foreign nonmacro checkpoint','truncated-season':'Missing nonmacro seasonal clock'}[defect]
        assert expected in stderr,stderr
        assert 'DAILY_ACCEPTED' not in (out/'kernel.stdout').read_text()
        assert not list(out.glob('accepted-*.zip'))
        results.append(dict(defect=defect,native_refusal=expected))
    report=dict(status='PASS',project=a.project,build_sha256=h.sha(a.bundle/'BUILD.json'),results=results)
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
finally:
    timer.cancel();h.start_process=actual
    for process in workers:
        if process.poll() is None:process.kill()
        process.wait(timeout=5)
