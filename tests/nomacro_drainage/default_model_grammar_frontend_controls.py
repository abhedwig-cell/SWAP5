"""Observe actual default-model lexical guards and unchanged process bounds."""
import argparse
from contextlib import ExitStack
import importlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import experimental_project as frontend
from default_model_grammar_postimages import OriginalStore


def observe(directory,module,policy):
    project=frontend.load(directory,original_output=True,time_step_policy=policy)
    owner=importlib.import_module(module)
    if module=='implicit_conductivity':
        text=(directory/'swap.swp').read_text(encoding='cp1252');report=frontend.inspect(directory,original_output=True)
        return owner.selection(text,frontend.switches(text),report['boundary'],original_output=True)
    return owner.enabled(project) if module=='implicit_groundwater_state' else owner.selection(project)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    oldroot=a.evidence/'signed-default-dispatch-assessment-v2';prior=json.loads((oldroot/'RESULT.json').read_text())
    assert prior['status']=='FOUR_ACTUAL_DEFAULT_MODEL_GUARD_GAPS_AND_TWELVE_REVIEWABLE_PARSER_ONLY_CANDIDATES_CONFIRMED_NOT_APPLIED'
    fixtures=[]
    for family,module in (('implicit','implicit_conductivity'),('groundwater','implicit_groundwater_state'),('snow-undrained','snow_undrained'),('snow-groundwater','snow_water_groundwater')):
        fixtures.append((family,module,oldroot/(family+'-unsigned'),'original-adaptive-day-seed-v1'))
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=[],compiler_executions=0,model_executions=0,new_full_periods=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    with ExitStack() as stack:
        store=OriginalStore(ROOT/'integration/f-ci/nomacro-complete01','HYDRAULIC_MODEL7_UNSELECTED_WINDOWS_RAW_V1',stack)
        previous=json.loads(store.get('profiles/model7-unselected-postimages-O0-v4/RESULT.json'));projection=json.loads(store.get('INPUT_PROJECTION_V1.json'))
        for kind in ('water','cde'):
            item=previous['profiles']['implicit-frost-'+kind];directory=a.output/('frost-'+kind+'-original');directory.mkdir()
            prefix=projection[item['input_root']]['archive_prefix']
            for name,digest in projection[item['input_root']]['files'].items():
                raw=store.get(prefix+'/'+name);path=directory/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
            fixtures.append(('frost-'+kind,'implicit_conductivity',directory,item['time_policy']))
        valid=(None,'1','+1','01','+0001','+01 001','1 1')
        invalid=('0','-1','2','12','++1','1.0','+ 1','1\nIHWCKmodel = 1')
        for family,module,original,policy in fixtures:
            original_raw=(original/'swap.swp').read_text(encoding='cp1252')
            base=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*\r?\n?','',original_raw)
            baseline=observe(original,module,policy);assert baseline
            for index,literal in enumerate(valid+invalid):
                directory=a.output/(family+'-'+str(index));directory.mkdir()
                for file in original.glob('*'):
                    assert file.is_file();(directory/file.name).write_bytes(file.read_bytes())
                text=base if literal is None else base+'\nIHWCKmodel = '+literal+'\n'
                (directory/'swap.swp').write_text(text,encoding='cp1252')
                try:actual=observe(directory,module,policy);error=None
                except ValueError as exc:actual=None;error=str(exc)
                if index<len(valid):assert actual==baseline,(family,literal,error)
                else:assert not actual,(family,literal,actual)
                q['checks'].append(dict(family=family,module=module,time_policy=policy,literal=literal,
                    role='EXACT_EXISTING_UNSIGNED_SELECTION' if index<len(valid) else 'OUTSIDE_DEFAULT_MODEL1_REMAINS_UNSELECTED_OR_REFUSED',
                    selected=actual,error=error,input_root=str(directory),input_inventory=frontend.inventory(directory)));save()
    assert len(q['checks'])==90
    q['status']='SIX_ACTUAL_DEFAULT_MODEL_DOMAINS_42_SPELLING_EQUIVALENCES_48_NONDEFAULT_REFUSALS_OR_UNSELECTED_PASS';save();print(q['status'])


if __name__=='__main__':main()
