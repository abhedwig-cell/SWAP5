"""Derive new hysteresis inputs by one byte from each sealed Snow9 fixture."""
import argparse,hashlib,json,re,subprocess,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA

ROOT=Path(__file__).resolve().parents[2]
BASE='2a14f2094bfbfb29c169eb6331da1d7829faa70a'
PARENT_SHA='cb78947e988ddfc8fc8e5000cc54438912d00bc55588ea5f5683fcd24706a1b1'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);a=parser.parse_args()
    a.output.mkdir();proof=ROOT/'integration/f-ci/nomacro-complete01';files={};roles=[];cases=[]
    original=(proof/'EXPLICIT_BOTTOM9_SNOW_INPUTS_V1.json').read_bytes().replace(b'\r\n',b'\n')
    assert original==subprocess.check_output(['git','show',BASE+':integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_INPUTS_V1.json'],cwd=ROOT)
    with ExitStack() as stack:
        parent=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_INPUTS_V1',stack);assert parent.record['sha256']==PARENT_SHA
        for role in parent.record['roles']:
            for history in (1,2):
                label=role+'-hys'+str(history);roles.append(label);folder=a.output/label;folder.mkdir();before={};after={}
                for name in parent.names:
                    if not name.startswith(role+'/'):continue
                    member=name[len(role)+1:];assert Path(member).name==member
                    raw=parent.get(name);changed=raw
                    if member=='swap.swp':
                        changed,count=re.subn(rb'(?m)^([ \t]*SWHYST[ \t]*=[ \t]*)0(?=[ \t!\r\n])',lambda m:m[1]+str(history).encode(),raw)
                        assert count==1 and len(raw)==len(changed) and sum(x!=y for x,y in zip(raw,changed))==1
                    before[member]=SHA(raw);after[member]=SHA(changed);(folder/member).write_bytes(changed);files[label+'/'+member]=changed
                assert {n for n in before if before[n]!=after[n]}=={'swap.swp'}
                cases.append(dict(role=label,original_role=role,hysteresis=history,original_inventory=before,input_inventory=after,only_changed_field='SWHYST',changed_bytes=1))
    assert len(cases)==8 and len(files)==80
    receipt=dict(status='EIGHT_NEW_SNOW_HISTORY_INPUT_CONTEXTS_ONLY_ONE_HYSTERESIS_BYTE_CHANGED_FROM_EACH_IMMUTABLE_PARENT',actual_canonical=BASE,parent_input_archive_sha256=PARENT_SHA,cases=cases,model_executions=0,compiler_executions=0,canonical_admission=False)
    files['INPUT_DERIVATION_V1.json']=json.dumps(receipt,indent=2).encode();files['actual-input-generator.py']=Path(__file__).read_bytes()
    name='EXPLICIT_BOTTOM9_SNOW_HISTORY_INPUTS_V1';archive=proof/(name+'.zip');assert not archive.exists()
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for member,raw in sorted(files.items()):z.writestr(member,raw)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and set(z.namelist())==set(files)
        for member,raw in files.items():assert z.read(member)==raw
    raw=archive.read_bytes();record=dict(archive=archive.name,bytes=len(raw),sha256=SHA(raw),parts=[dict(file=archive.name,bytes=len(raw),sha256=SHA(raw))],members={n:dict(bytes=len(v),sha256=SHA(v)) for n,v in files.items()},roles=roles,parent_input_archive_sha256=PARENT_SHA,canonical_admission=False)
    with archive.with_suffix('.json').open('x') as f:json.dump(record,f,indent=2)
    with (a.output/'INPUT_DERIVATION_V1.json').open('x') as f:json.dump(receipt,f,indent=2)
    print(receipt['status'],len(raw),record['sha256'])


if __name__=='__main__':main()
