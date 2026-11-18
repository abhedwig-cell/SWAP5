"""Real original Fortran CDE wire and actual false-proposal stock controls."""
import argparse
import json
from pathlib import Path
import struct
from types import SimpleNamespace
import zipfile
import original_output_matrix as matrix
from cde_native_receipt import decode,validate_candidate,metadata

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('diagnostic-root','build-json','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();diagnostic=json.loads((a.diagnostic_root/'RESULT.json').read_text());build=json.loads(a.build_json.read_text());project=SimpleNamespace(nodes=build['project']['nodes']);source=Path(diagnostic['positive']['private_candidate']);digest=m.sha(source)
    with zipfile.ZipFile(source) as z:aux=z.read('macro.bin')
    receipt=dict(solute_end_mg_cm2=diagnostic['positive']['reported_stock_mg_cm2']);actual=validate_candidate(aux,receipt,project);assert actual==diagnostic['positive']['actual_native_stock_mg_cm2']==decode(aux,project.nodes);checks=[]
    def refuse(name,raw,reported,nodes):
        try:validate_candidate(raw,dict(solute_end_mg_cm2=reported),SimpleNamespace(nodes=nodes))
        except ValueError as error:checks.append(dict(attack=name,status='REFUSED',error=str(error)))
        else:raise AssertionError('Invalid actual CDE stock receipt accepted: '+name)
    refuse('actual-fabricated-proposal',aux,diagnostic['negative']['reported_stock_mg_cm2'],project.nodes)
    for label,value in [('changed',actual+1),('negative',-1.),('nan',float('nan')),('infinite',float('inf')),('boolean',True),('string',str(actual)),('missing',None)]:refuse('reported-'+label,aux,value,project.nodes)
    for label,offset,value in [('soil-negative',48,-1.),('soil-nan',48,float('nan')),('surface-negative',48+8*project.nodes,-1.),('stock-nan',48+8*(project.nodes+1),float('nan')),('stock-changed',48+8*(project.nodes+1),actual+1)]:
        raw=bytearray(aux);struct.pack_into('<d',raw,offset,value);refuse('native-'+label,raw,actual,project.nodes)
    for label,raw,n in [('empty',b'',project.nodes),('truncated',aux[:48+8*(project.nodes+2)-1],project.nodes),('zero-shape',aux,0),('negative-shape',aux,-1),('boolean-shape',aux,True),('oversized-shape',aux,1001)]:refuse(label,raw,actual,n)
    assert m.sha(source)==digest and len(checks)==19
    q=dict(status='ACTUAL_CDE_NATIVE_STOCK_COMPONENT_NINETEEN_REFUSALS_PASS',policy=metadata(),actual_fortran_wire=True,nodes=project.nodes,native_stock_mg_cm2=actual,actual_wire_source_sha256=digest,actual_old_build_sha256=m.sha(a.build_json),refusals=checks,source_unchanged=True,no_old_build_rebinding=True)
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],flush=True)


if __name__=='__main__':main()
