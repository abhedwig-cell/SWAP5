"""Real generated original reader faults, separately from descriptor binding."""
import argparse
import contextlib
import json
from pathlib import Path
import shutil
import age_irrigation_source_matrix as matrix

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--young-build',type=Path);p.add_argument('--young-input',type=Path)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();cohort=json.loads((a.matrix_root/'RESULT.json').read_text());c=cohort['cases']['surface-daily'];inputs=Path(c['input_root']);build=Path(c['build_root']);project=m.e.load(inputs,age_irrigation_source=True);meta,case=m.validate_bundle(build,a.reference_work,project)
    q=dict(status='RUNNING',actual_build_sha256=m.sha(build/'BUILD.json'),scope='Reader-only fault injection after independent successful bundle validation; original accepted input files unchanged',reader_refusals=[],descriptor_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def refuse(label,actual_build,actual_case,actual_project,binding,need):
        out=a.output/label;out.mkdir()
        try:
            with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(actual_build,'day_donor'),m.h.executable(actual_build,'day_kernel'),actual_case,out,[m.h.ColumnStart('original',0)],runtime=True,checkpoint_enabled=True,binding=binding,model=actual_project.model,project=actual_project)
        except (ValueError,RuntimeError) as error:
            diagnostics='\n'.join(p.read_text(errors='replace') for pattern in ('donor.stderr','donor.stdout','swap.log','swap.err') for p in out.rglob(pattern));assert not list(out.glob('accepted-*.zip')) and 'HYBRID_READY' not in diagnostics,(label,diagnostics)
            assert any(word in (diagnostics+str(error)).lower() for word in need),(label,diagnostics,str(error));return dict(attack=label,status='REFUSED_BEFORE_HYBRID_READY',error=str(error),diagnostic=diagnostics[-12000:])
        raise AssertionError('Invalid fixed-age input accepted: '+label)
    try:
        for label,value in [('negative','-1.0'),('upper','1001.0'),('nan','NaN'),('infinity','Inf'),('not-numeric','invalid')]:
            bad=a.output/('input-'+label);shutil.copytree(case,bad);p=bad/'fixed-irrigation.irg';text=p.read_text();assert '2002-01-05 24.0 20.0' in text;p.write_text(text.replace('2002-01-05 24.0 20.0','2002-01-05 24.0 '+value,1));q['reader_refusals'].append(refuse('reader-'+label,build,bad,project,meta['binding'],('irconc','irrigation age','invalid','number')));save()
        bad=a.output/'input-subsurface';shutil.copytree(case,bad);p=bad/'fixed-irrigation.irg';text=p.read_text();assert '2002-01-05 24.0 20.0 1 12.0' in text;p.write_text(text.replace('2002-01-05 24.0 20.0 1 12.0','2002-01-05 24.0 20.0 2 12.0',1)+'\nIR_Z = -30.0\n');q['reader_refusals'].append(refuse('reader-subsurface',build,bad,project,meta['binding'],('sprinkler and surface',)));save()
        from original_output_baseline import assignment
        for key,value in [('SWSOLU',1),('SWIRFIX',0),('SWFROST',1),('SWSNOW',1),('SWBR',1),('SWSOPHY',1),('SWMETDETAIL',1)]:
            bad=a.output/('descriptor-'+key);shutil.copytree(inputs,bad);p=bad/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            try:m.e.load(bad,age_irrigation_source=True)
            except ValueError as error:q['descriptor_refusals'].append(dict(key=key,value=value,status='REFUSED',error=str(error)))
            else:raise AssertionError('Unsupported fixed-age source descriptor accepted: '+key)
        if a.young_build:
            assert a.young_input;young_identity=json.loads((a.young_build/'BUILD.json').read_text())['identity'];young=m.e.load(a.young_input,original_output=young_identity.get('original_output') is not None);ym,ycase=m.validate_bundle(a.young_build,a.reference_work,young);bad=a.output/'input-old-young';shutil.copytree(ycase,bad);p=bad/'fixed-irrigation.irg';text=p.read_text();assert '2002-01-05 24.0 0.0' in text;p.write_text(text.replace('2002-01-05 24.0 0.0','2002-01-05 24.0 20.0',1));q['young_default_refusal']=refuse('young-default-positive',a.young_build,bad,young,ym['binding'],('requires zero-day young water',));q['young_build_sha256']=m.sha(a.young_build/'BUILD.json')
        assert m.validate_bundle(build,a.reference_work,project)[0]==meta
        q['status']='SIX_REAL_FIXED_AGE_READER_AND_SEVEN_DESCRIPTOR_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
