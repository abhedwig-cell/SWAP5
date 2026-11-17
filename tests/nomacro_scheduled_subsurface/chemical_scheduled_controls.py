"""Actual chemical reader refusals and interleaved conserved native origins."""
import argparse
import contextlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('scheduled_source',Path(__file__).with_name('chemical_scheduled.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
m=q.m;s=q.s


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir();reports=[]
    def save_progress():
        (out/'RESULT.json').write_text(json.dumps(dict(status='RUNNING',checks=reports),indent=2)+'\n')
    save_progress()
    for name,field,value in [('reversed','SS_IRR_Z','-20.0 -10.0'),('outside-domain','SS_IRR_Z','-101.0'),
                             ('nonfinite-depth','SS_IRR_Z','NaN'),('negative-concentration','CIRRS','-1.0'),('nonfinite-concentration','CIRRS','NaN')]:
        case=out/name;shutil.copytree(a.evidence/'input',case)
        crop=case/'maize.crp';crop.write_text(s.assignment(crop.read_text(encoding='cp1252'),field,value),encoding='cp1252')
        project=m.e.load(case)
        for opt in ('O0','O2'):
            build=a.evidence/(opt+'-build');target=out/(name+'-'+opt);target.mkdir()
            try:
                m.bounded(20,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,300,runtime=True,model=project.model,project=project))
            except RuntimeError as error:
                diagnostic='\n'.join(path.read_text(errors='replace') for pattern in ('donor.stderr','swap.err') for path in target.rglob(pattern))
                expected='depth interval/profile' if name=='reversed' else field
                require=expected.upper() in diagnostic.upper() or (name=='nonfinite-concentration' and 'Invalid conserved subsurface solute source' in diagnostic)
                assert require,diagnostic
                assert not list(target.glob('accepted-*.zip'))
                reports.append(dict(test=name,optimization=opt,status='REFUSED',diagnostic=diagnostic,error=str(error)))
                save_progress()
            else:raise AssertionError('Invalid original chemical scheduled input accepted: '+name)
    for opt in ('O0','O2'):
        build=a.evidence/(opt+'-build');project=m.e.load(a.evidence/'input');meta,case=m.validate_bundle(build,a.reference_work,project)
        full=a.evidence/(opt+'-full');data=m.rows(full);target=out/(opt+'-interleaved');target.mkdir()
        starts=[544,530];origins=[]
        for index,start in enumerate(starts):
            source=full/f'accepted-column-1-day-{start}.zip';digest=m.sha(source);origin=target/('origin'+str(index))
            receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin)
            origins.append((source,digest,m.h.ColumnStart('original',start,origin,receipt,name='column'+str(index))))
        with contextlib.ExitStack() as stack:
            host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                              [value[2] for value in origins],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            for turn in range(3):
                for column,start in enumerate(starts,1):
                    row=host.step(column)
                    assert m.physical([row])==m.physical([data[start+turn]])
                    if column==1 and turn==0:assert row['solute_ledger_mg_cm2'][3]>0
            host.close()
        assert all(m.sha(source)==digest for source,digest,_ in origins)
        reports.append(dict(test='independent-native-origins',optimization=opt,status='PASS',alternating_steps=6,active_source=True,physical_exact=True,origins_unchanged=True))
        save_progress()
    result=dict(status='SCHEDULED_CHEMICAL_NATIVE_INPUT_AND_INDEPENDENT_ORIGINS_PASS',checks=reports,
                source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip())
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)


if __name__=='__main__':main()
