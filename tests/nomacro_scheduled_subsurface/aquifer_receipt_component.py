"""Real Fortran native bytes through the actual aquifer receipt validator."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
from types import SimpleNamespace
import zipfile
import output_aquifer_runtime as runtime
from aquifer_native_receipt import decode,validate_candidate,metadata

m=runtime.m


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):ap.add_argument('--'+key,type=Path,required=True)
    a=ap.parse_args();a.output.mkdir();p=m.e.load(a.profile_root/'input',original_output=True);meta,case=m.validate_bundle(a.profile_root/'build',a.reference_work,p)
    source=a.profile_root/'trajectory/accepted-column-1-day-4.zip';receipt=m.h.verify_checkpoint(source,4,meta['binding'],a.output/'origin')
    with zipfile.ZipFile(source) as z:aux=z.read('macro.bin')
    actual=validate_candidate(aux,receipt,p);assert actual==receipt['aquifer_state'];offset=48+8*(p.nodes+2);checks=[]
    for field in range(7):
        changed={**receipt,'aquifer_state':receipt['aquifer_state'].copy()};changed['aquifer_state'][field]+=1.
        try:validate_candidate(aux,changed,p)
        except ValueError as error:checks.append(dict(attack='reported-'+str(field),status='REFUSED',error=str(error)))
        else:raise AssertionError('Actual native/report disagreement accepted')
        raw=bytearray(aux);values=actual.copy();values[field]+=1;struct.pack_into('<6dq',raw,offset,*values[:6],int(values[6]))
        try:validate_candidate(raw,receipt,p)
        except ValueError as error:checks.append(dict(attack='native-'+str(field),status='REFUSED',error=str(error)))
        else:raise AssertionError('Actual native/receipt mismatch accepted')
    changed={**receipt,'solute_end_mg_cm2':receipt['solute_end_mg_cm2']+1.}
    try:validate_candidate(aux,changed,p)
    except ValueError as error:checks.append(dict(attack='soil-stock',status='REFUSED',error=str(error)))
    else:raise AssertionError('Native soil stock mismatch accepted')
    for label,raw,n in [('truncated',aux[:offset+55],p.nodes),('empty',b'',p.nodes),('zero-shape',aux,0),('negative-shape',aux,-1),('boolean-shape',aux,True)]:
        try:validate_candidate(raw,receipt,SimpleNamespace(nodes=n))
        except ValueError as error:checks.append(dict(attack=label,status='REFUSED',error=str(error)))
        else:raise AssertionError('Incomplete or foreign native source shape accepted')
    assert m.sha(source)==m.sha(source)
    q=dict(status='ACTUAL_AQUIFER_NATIVE_RECEIPT_COMPONENT_TWENTY_REFUSALS_PASS',policy=metadata(),actual_fortran_wire=True,native_offset=offset,actual_aquifer_state=actual,build_sha256=m.sha(a.profile_root/'build/BUILD.json'),refusals=checks)
    assert len(checks)==20;(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],flush=True)


if __name__=='__main__':main()
