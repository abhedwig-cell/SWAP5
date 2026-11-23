"""Derive representative existing Snow calendars and hysteresis configurations."""
import argparse,json,re,zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA

ROOT=Path(__file__).resolve().parents[2]
PARENT_SHA='cb78947e988ddfc8fc8e5000cc54438912d00bc55588ea5f5683fcd24706a1b1'


def set_value(raw,key,value):
    pattern=rb'(?mi)^([ \t]*'+key.encode()+rb'[ \t]*=[ \t]*)([^!\r\n]*)'
    matches=list(re.finditer(pattern,raw));assert len(matches)==1,key
    found=matches[0];old=found[2].strip();assert old
    return raw[:found.start(2)]+str(value).encode()+raw[found.end(2):],old.decode()


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    proof=ROOT/'integration/f-ci/nomacro-complete01';files={};roles=[];cases=[]
    with ExitStack() as stack:
        store=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_INPUTS_V1',stack);assert store.record['sha256']==PARENT_SHA
        for kind in ('water','cde'):
            choices=[(0,'subdaily'),(0,'monthly'),(1,'subdaily'),(2,'monthly'),(1 if kind=='water' else 2,'step-reset')]
            for history,mode in choices:
                for initial in (1,2):
                    role=kind+'-initial'+str(initial);label=role+'-hys'+str(history)+'-'+mode;roles.append(label);folder=a.output/label;folder.mkdir();before={};after={};changes=[]
                    values=dict(SWHYST=history,NPRINTDAY=3 if mode=='subdaily' else 1,SWMONTH=int(mode=='monthly'),PERIOD=0 if mode=='monthly' else 1,SWRES=0 if mode=='monthly' else 1,FLPRINTDT='.TRUE.' if mode=='step-reset' else '.FALSE.')
                    for name in store.names:
                        if not name.startswith(role+'/'):continue
                        member=name[len(role)+1:];assert Path(member).name==member;raw=store.get(name);changed=raw
                        if member=='swap.swp':
                            for key,value in values.items():
                                changed,old=set_value(changed,key,value)
                                if old!=str(value):changes.append(dict(field=key,old=old,new=str(value)))
                        before[member]=SHA(raw);after[member]=SHA(changed);(folder/member).write_bytes(changed);files[label+'/'+member]=changed
                    assert {n for n in before if before[n]!=after[n]}=={'swap.swp'} and changes
                    cases.append(dict(role=label,original_role=role,kind=kind,initial=initial,hysteresis=history,calendar=mode,changed_fields=changes,original_inventory=before,input_inventory=after))
    assert len(cases)==20 and len(files)==200
    receipt=dict(status='TWENTY_REPRESENTATIVE_SNOW_CALENDAR_INPUTS_ONLY_DECLARED_HYSTERESIS_AND_OUTPUT_CONTROLS_CHANGED',parent_input_archive_sha256=PARENT_SHA,cases=cases,all_meteo_soil_crop_irrigation_and_physical_forcing_bytes_unchanged=True,model_executions=0,compiler_executions=0,canonical_admission=False)
    files['INPUT_DERIVATION_V1.json']=json.dumps(receipt,indent=2).encode();files['actual-input-generator.py']=Path(__file__).read_bytes()
    name='EXPLICIT_BOTTOM9_SNOW_HISTORY_CALENDAR_INPUTS_V1';archive=proof/(name+'.zip');assert not archive.exists()
    with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for name,raw in sorted(files.items()):z.writestr(name,raw)
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and set(z.namelist())==set(files)
        for name,raw in files.items():assert z.read(name)==raw
    raw=archive.read_bytes();record=dict(archive=archive.name,bytes=len(raw),sha256=SHA(raw),parts=[dict(file=archive.name,bytes=len(raw),sha256=SHA(raw))],members={n:dict(bytes=len(v),sha256=SHA(v)) for n,v in files.items()},roles=roles,cases=cases,parent_input_archive_sha256=PARENT_SHA,canonical_admission=False)
    with archive.with_suffix('.json').open('x') as f:json.dump(record,f,indent=2)
    with (a.output/'INPUT_DERIVATION_V1.json').open('x') as f:json.dump(receipt,f,indent=2)
    print(receipt['status'],len(raw),record['sha256'])


if __name__=='__main__':main()
