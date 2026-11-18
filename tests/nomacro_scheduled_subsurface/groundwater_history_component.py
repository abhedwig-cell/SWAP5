"""Real Fortran history wire and actual read-only production decoder contract."""
import argparse
import json
from pathlib import Path
import struct
import zipfile
import groundwater_history_runtime as runtime
from groundwater_history_native import decode,domain,validate_candidate

m=runtime.m


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir();profile=json.loads((args.profile_root/'RESULT.json').read_text())
    project=m.e.load(Path(profile['input_root']),original_output=profile['original_output']);build=Path(profile['build_root'])
    meta,_=m.validate_bundle(build,args.reference_work,project);source=args.profile_root/'trajectory/accepted-column-1-day-4.zip';digest=m.sha(source)
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    receipt=m.rows(args.profile_root/'trajectory')[3];validate_candidate(raw,receipt,project)
    actual=decode(raw,project);offset=actual['offset'];n=project.nodes;start=offset-104;checks=[]
    def refuse(label,wire,report=receipt):
        try:validate_candidate(wire,report,project)
        except ValueError as error:checks.append(dict(attack=label,status='REFUSED',error=str(error)))
        else:raise AssertionError('Invalid actual groundwater history native receipt accepted: '+label)
    for i in range(13):
        changed=bytearray(raw);value=domain(project)[i]+1
        for base in (start,start+52):struct.pack_into('<i',changed,base+4*i,value)
        refuse('domain-'+str(i),changed)
    changed=bytearray(raw);struct.pack_into('<i',changed,start,3);refuse('domain-witness',changed)
    for i in (0,n,2*n,3*n+1,4*n+2,5*n+2,5*n+3):
        changed=bytearray(raw);struct.pack_into('<d',changed,offset+8*i,float('nan'));refuse('native-nonfinite-'+str(i),changed)
    for i in (n,2*n,3*n+1,4*n+2,5*n+3):
        changed=bytearray(raw);struct.pack_into('<d',changed,offset+8*i,-1.);refuse('native-negative-'+str(i),changed)
    for label,field in [('reported-level','groundwater_cm'),('reported-head','pressure_head_cm'),('reported-stock','stock_end_cm')]:
        changed=dict(receipt)
        if isinstance(changed[field],list):changed[field]=changed[field].copy();changed[field][0]+=1.
        else:changed[field]+=1.
        refuse(label,raw,changed)
    for label,wire in [('empty',b''),('truncated-domain',raw[:start+100]),('truncated-carry',raw[:offset+8*(5*n+4)-1])]:refuse(label,wire)
    for codec in (b'S5GWC001',b'S5ITC001',b'S5IHC001'):
        changed=bytearray(raw);changed[:8]=codec;refuse('foreign-codec-'+codec.decode(),changed)
    for label,i in [('changed-level',5*n+2),('changed-volume',5*n+3),('changed-head',0)]:
        changed=bytearray(raw);old=struct.unpack_from('<d',changed,offset+8*i)[0];struct.pack_into('<d',changed,offset+8*i,old+1.);refuse(label,changed)
    assert len(checks)==38 and m.sha(source)==digest
    record=dict(status='ACTUAL_GROUNDWATER_HISTORY_NATIVE_COMPONENT_THIRTY_EIGHT_REFUSALS_PASS',actual_fortran_wire=True,
        source_checkpoint_sha256=digest,build_sha256=m.sha(build/'BUILD.json'),native_policy=meta['identity']['groundwater_native_state'],
        actual_domain=domain(project),native_heads_and_stock_exact=True,source_unchanged=True,refusals=checks,
        original_physical_or_state_mock_used=False,physical_equations_changed=False)
    (args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    print(record['status'],flush=True)


if __name__=='__main__':main()
