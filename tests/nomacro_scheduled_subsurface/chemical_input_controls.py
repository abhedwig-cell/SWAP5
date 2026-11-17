"""Original fixed chemical file/inline equality and native invalid-depth reader."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('chemical_fixed',Path(__file__).with_name('chemical_fixed.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
m=q.m


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--evidence-root',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();out=a.output.resolve();out.mkdir();reports=[]
    for kind in ('point','interval'):
        file=a.evidence_root/('chemical-fixed-'+kind+'-full')
        inline=a.evidence_root/('chemical-fixed-'+kind+'-inline')
        for opt in ('O0','O2'):
            assert m.physical(m.rows(inline/(opt+'-full')))==m.physical(m.rows(file/(opt+'-full'))[:8])
            assert m.csvlines(inline/(opt+'-full/original/result_output.csv'))==m.csvlines(file/(opt+'-full/original/result_output.csv'))[:10]
            reports.append(dict(test='file-inline',configuration=kind,optimization=opt,days=8,physical_csv_exact=True))
    prior=a.evidence_root/'chemical-fixed-interval-full'
    for name,value in [('reversed','-40.0 -20.0'),('outside-domain','-101.0'),('nonfinite','NaN')]:
        case=out/name;shutil.copytree(prior/'input',case)
        irrigation=case/'fixed-irrigation.irg'
        text,count=re.subn(r'(?mi)^IR_Z\s*=[^\r\n]+','IR_Z = '+value,irrigation.read_text());assert count==1
        irrigation.write_text(text)
        project=m.e.load(case)
        for opt in ('O0','O2'):
            build=prior/(opt+'-build');target=out/(name+'-'+opt);target.mkdir()
            try:
                m.bounded(10,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,2,
                                          runtime=True,model=project.model,project=project))
            except RuntimeError as error:
                diagnostic='\n'.join(path.read_text(errors='replace') for pattern in ('donor.stderr','swap.err') for path in target.rglob(pattern))
                assert ('depth interval/profile' in diagnostic if name=='reversed' else 'IR_Z' in diagnostic.upper()),diagnostic
                assert not list(target.glob('accepted-*.zip'))
                reports.append(dict(test=name,optimization=opt,status='REFUSED',diagnostic=diagnostic,error=str(error)))
            else:raise AssertionError('Invalid native fixed chemical irrigation depth accepted: '+name)
    result=dict(status='FIXED_CHEMICAL_FILE_INLINE_AND_NATIVE_INPUT_CONTROLS_PASS',checks=reports,
                source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip())
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)


if __name__=='__main__':main()
