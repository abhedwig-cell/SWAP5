"""Seal existing calendar observations; never execute or relabel a model."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from weather_surface_seal import archive


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('evidence','output','provider','current-source'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args()
    for opt in ('O0','O2'):
        directories=[];builds=[]
        def add(prefix,name):
            root=a.evidence/name;q=json.loads((root/'RESULT.json').read_text())
            directories.append((prefix,root));builds.append((prefix+'-build',Path(q['build_root'])))
        for label in ('water','cde'):
            add('full-'+label,f'calendar-full-{opt}-v1-{label}')
            add('current-'+label,f'calendar-current-{opt}-v1-{label}')
        for case in ('water','automatic'):add('compatibility-'+case,f'calendar-compatibility-{case}-{opt}-v1')
        for label in ('limit','format0','format0-terminal'):add(label,f'calendar-{label}-{opt}-v1')
        add('short-cde',f'calendar-short-automatic-daily-{opt}-v1')
        for mode in ('subdaily','monthly','combined','perstep'):
            name=f'calendar-short-water-{mode}-{opt}-v1'
            if mode=='subdaily' and opt=='O2':name='extended-calendar-subdaily-water-O2-v2'
            add('short-'+mode,name)
        directories.append(('named-seam',a.evidence/f'calendar-named-{opt}-v1'))
        # Named seam records a different result schema; its own actual build
        # resides in the registered variant directory, without copying objects.
        builds.append(('named-build',a.evidence.parent/f'extended-calendar-{opt}-v1/named-v1'))
        q=archive(a.output,f'EXTENDED_DRAINAGE_CALENDAR_WINDOWS_{opt}_RAW_ARCHIVE',directories,[],builds)
        print(opt,q['bytes'],q['sha256'],flush=True)
    files=[('provider-PREPARED.json',a.provider/'PREPARED.json')]
    q=archive(a.output,'EXTENDED_DRAINAGE_CALENDAR_WINDOWS_SOURCE_RAW_ARCHIVE',
              [('full-source',a.evidence/'extended-calendar-windows-source-v1'),('source',a.current_source)],files)
    print('SOURCE',q['bytes'],q['sha256'])


if __name__=='__main__':main()
