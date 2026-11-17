"""Negative inputs exercised through actual original reader and public preflight."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('scheduled_ssdi',ROOT/'tests/nomacro_scheduled_subsurface/run.py')
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    reference=a.reference_work.resolve();prior=a.evidence.resolve();reports=[]
    source=prior/'input'
    # Chemical SSDI must also be refused when it occurs only in a future crop.
    chemical=out/'chemical';shutil.copytree(source,chemical)
    control=chemical/'swap.swp';control.write_text(q.assignment(control.read_text(encoding='cp1252'),'SWSOLU',1),encoding='cp1252')
    for crop in chemical.glob('*.crp'):
        if crop.name!='grass.crp':crop.write_text(q.assignment(crop.read_text(encoding='cp1252'),'ISUAS',1),encoding='cp1252')
    try:q.m.e.load(chemical)
    except ValueError as error:assert 'separate conserved mass owner' in str(error);reports.append(dict(test='future-chemical-SSDI',status='REFUSED',error=str(error)))
    else:raise AssertionError('Future chemical SSDI accepted')
    # These inputs deliberately call the actual compiled original reader,
    # bypassing only bundle reuse (not publishing a rebound build/checkpoint).
    # Each starts cold, has no foreign origin, and must terminate when the crop
    # actually emerges and initializes scheduling. Its nominal sowing date does
    # not activate the reader. Real Fortran diagnostics establish the cause.
    for name,value in [('reversed','-20.0 -10.0'),('outside-domain','-101.0'),('nonfinite','NaN')]:
        case=out/name;shutil.copytree(source,case)
        crop=case/'maize.crp';crop.write_text(q.assignment(crop.read_text(encoding='cp1252'),'SS_IRR_Z',value),encoding='cp1252')
        project=q.m.e.load(case)
        for opt in ('O0','O2'):
            build=prior/(opt+'-build');target=out/(name+'-'+opt);target.mkdir()
            try:
                q.m.bounded(20,lambda:q.m.h.run(q.m.h.executable(build,'day_donor'),q.m.h.executable(build,'day_kernel'),case,target,300,
                                             runtime=True,model=project.model,project=project))
            except RuntimeError as error:
                diagnostic='\n'.join(path.read_text(errors='replace') for path in target.rglob('donor.stderr'))
                diagnostic+='\n'+'\n'.join(path.read_text(errors='replace') for path in target.rglob('swap.err'))
                assert ('depth interval/profile' in diagnostic if name=='reversed' else ('SS_IRR_Z' in diagnostic.upper())),diagnostic
                assert not list(target.glob('accepted-*.zip'))
                reports.append(dict(test=name,optimization=opt,status='REFUSED',diagnostic=diagnostic,error=str(error)))
            else:raise AssertionError('Invalid native SSDI input accepted: '+name)
    # Resume the actual active window on unchanged production source; no full
    # period or compilation is repeated to finish these stronger transactions.
    for opt in ('O0','O2'):
        project=q.m.e.load(source);active=out/(opt+'-active');active.mkdir()
        reports.append(dict(test='actual-active-scheduled-transactions',optimization=opt,
                            result=q.active_own(prior/(opt+'-build'),reference,project,prior/(opt+'-full'),q.m.rows(prior/(opt+'-full')),active)))
    result=dict(status='SCHEDULED_SSDI_ORIGINAL_READER_AND_ACTIVE_TRANSACTIONS_PASS',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),checks=reports)
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)


if __name__=='__main__':main()
