"""Read exact native CDE stock and attack its shifted prefix without model runs."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import cde_native_receipt as native
import experimental_project as e


def audit(profile):
    q=json.loads((profile/'RESULT.json').read_text());assert q['kind']=='cde'
    project=e.load(q['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    rows=[json.loads(line) for line in (profile/'trajectory/daily.jsonl').read_text().splitlines()]
    observations=[];payload=None
    for path in sorted((profile/'trajectory').glob('accepted-column-1-day-*.zip')):
        day=int(path.stem.rsplit('-',1)[1]);expected=rows[day-1]['solute_end_mg_cm2']
        with zipfile.ZipFile(path) as archive:raw=archive.read('macro.bin')
        assert raw[:8]==b'S5HVC003'
        assert native.validate_candidate(raw,dict(solute_end_mg_cm2=expected),project)==expected
        observations.append(dict(day=day,stock=expected,checkpoint_sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        if day==532:payload=raw;stock=expected
    assert payload is not None and len(observations)==14
    layers=struct.unpack_from('<i',payload,56)[0];count=14+2*layers;size=4*count;offset=48+2*size+8*(project.nodes+1)
    refusals=[]
    for kind in ('domain','witness'):
        for index in range(count):
            raw=bytearray(payload);old=struct.unpack_from('<i',raw,48+4*index)[0]
            struct.pack_into('<i',raw,48+4*index,old+1)
            if kind=='domain':struct.pack_into('<i',raw,48+size+4*index,old+1)
            try:native.validate_candidate(raw,dict(solute_end_mg_cm2=stock),project)
            except ValueError:refusals.append(kind+'-'+str(index))
            else:raise AssertionError('Malformed vapor CDE context accepted')
    for label,value in (('stock-nan',float('nan')),('stock-negative',-1.),('stock-receipt-mismatch',stock+1.)):
        raw=bytearray(payload);struct.pack_into('<d',raw,offset,value)
        try:native.validate_candidate(raw,dict(solute_end_mg_cm2=stock),project)
        except ValueError:refusals.append(label)
        else:raise AssertionError('Malformed actual native stock accepted')
    assert len(refusals)==2*count+3
    return dict(status='INDEPENDENT_EXACT_VAPOR_CDE_NATIVE_PREFIX_STOCK_AND_REFUSALS_PASS_NOT_ADMITTED',
        observations=observations,refusals=refusals,actual_decoder_sha256=hashlib.sha256(Path(native.__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        model_executions=0,compiler_executions=0,public_admission=False)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('profile','output'):parser.add_argument('--'+name,type=Path,required=True)
    a=parser.parse_args();q=audit(a.profile)
    with a.output.open('x',encoding='utf8') as stream:stream.write(json.dumps(q,indent=2)+'\n')
    print(q['status'],len(q['observations']),len(q['refusals']))
