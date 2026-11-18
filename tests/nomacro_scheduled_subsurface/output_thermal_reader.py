"""Real generated original reader faults, separately from descriptor binding."""
import argparse
import contextlib
import json
import re
from pathlib import Path
import shutil
import output_thermal_runtime as matrix

m=matrix.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--young-build',type=Path);p.add_argument('--young-input',type=Path)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();cohort=json.loads((a.matrix_root/'RESULT.json').read_text());c=cohort['cases']['water-hys2-csv3'];inputs=Path(c['input_root']);build=Path(c['build_root']);project=m.e.load(inputs,original_output=True);meta,case=m.validate_bundle(build,a.reference_work,project)
    q=dict(status='RUNNING',actual_build_sha256=m.sha(build/'BUILD.json'),scope='Reader-only fault injection after independent successful bundle validation; original accepted input files unchanged',reader_refusals=[],descriptor_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def refuse(label,actual_build,actual_case,actual_project,binding,need):
        out=a.output/label;out.mkdir()
        try:
            with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(actual_build,'day_donor'),m.h.executable(actual_build,'day_kernel'),actual_case,out,[m.h.ColumnStart('original',0)],runtime=True,checkpoint_enabled=True,binding=binding,model=actual_project.model,project=actual_project)
        except (ValueError,RuntimeError) as error:
            diagnostics='\n'.join(p.read_text(errors='replace') for pattern in ('donor.stderr','donor.stdout','swap.log','swap.err') for p in out.rglob(pattern));assert not list(out.glob('accepted-*.zip')) and 'HYBRID_READY' not in diagnostics,(label,diagnostics)
            assert any(word in (diagnostics+str(error)).lower() for word in need),(label,diagnostics,str(error));return dict(attack=label,status='REFUSED_BEFORE_HYBRID_READY',error=str(error),diagnostic=diagnostics[-12000:])
        raise AssertionError('Invalid snow input accepted: '+label)
    try:
        from original_output_baseline import assignment
        faults=[('SNOWINCO','-1.0'),('SNOWINCO','1001.0'),('TEPRRAIN','11.0'),('TEPRSNOW','-11.0'),('SNOWCOEF','-1.0'),('SNOWCOEF','11.0')]
        for index,(key,value) in enumerate(faults):
            label=key+'-'+str(index);bad=a.output/('input-'+label);shutil.copytree(case,bad);p=bad/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),key,value),encoding='cp1252')
            q['reader_refusals'].append(refuse('reader-'+label,build,bad,project,meta['binding'],(key.lower(),'range','invalid','aquifer')));save()
        for key,value in [('NPRINTDAY',2),('SWMONTH',1),('PERIOD',2),('FLPRINTDT','.TRUE.'),('SWBR',1),('SWHEA',0),('SWCALT',1),('SWDRA',2),('SWMETDETAIL',1)]:
            bad=a.output/('descriptor-'+key);shutil.copytree(inputs,bad);p=bad/'swap.swp';text=p.read_text(encoding='cp1252');text=assignment(text,key,value) if re.search(r'(?mi)^\s*'+key+r'\s*=',text) else text+'\n'+key+' = '+str(value)+'\n';p.write_text(text,encoding='cp1252')
            try:
                candidate=m.e.load(bad,original_output=True);matrix.metadata(candidate)
            except ValueError as error:q['descriptor_refusals'].append(dict(key=key,value=value,status='REFUSED',error=str(error)))
            else:raise AssertionError('Unsupported thermal output descriptor accepted: '+key)
        assert m.validate_bundle(build,a.reference_work,project)[0]==meta
        q['status']='SIX_REAL_SNOW_READER_AND_NINE_OUTPUT_DESCRIPTOR_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
