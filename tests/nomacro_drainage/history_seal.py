"""Seal existing history evidence, storing each reused compiler bundle once."""
import argparse
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from weather_surface_seal import archive


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('evidence','output','provider'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();work=a.evidence.parent
    for opt in ('O0','O2'):
        directories=[];builds={};profiles={}
        def add(prefix,name):
            root=a.evidence/name;q=json.loads((root/'RESULT.json').read_text());build=Path(q['build_root'])
            assert q['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS'
            if build not in builds:builds[build]=prefix+'-build'
            profiles[prefix]=dict(actual_build_prefix=builds[build],actual_build_sha256=q['trajectory']['build_sha256'],producer_source=q['source'])
            directories.append((prefix,root))
        for label,case,h in [('water','water',1),('cde','automatic',2)]:
            add('full-'+label,f'history-full-{case}-h{h}-{opt}-v1')
            add('current-'+label,f'history-current-{case}-h{h}-{opt}-v1')
        for case in ('water','automatic'):
            for h in (1,2):add(f'short-{case}-h{h}',f'history-short-{case}-h{h}-{opt}-v2')
            add('off-'+case,f'history-off-{case}-{opt}-v1')
        for mode,h in [('subdaily',1),('perstep',2)]:add('output-'+mode,f'history-output-{mode}-h{h}-{opt}-v1')
        index=a.evidence/f'HISTORY_{opt}_ACTUAL_COMPILED_ALIASES_V1.json'
        with index.open('x') as stream:json.dump(dict(status='EXACT_ACTUAL_REUSED_BUILD_CUSTODY_NO_REBINDING',profiles=profiles),stream,indent=2)
        q=archive(a.output,f'EXTENDED_DRAINAGE_HISTORY_WINDOWS_{opt}_RAW_ARCHIVE',directories,[('ACTUAL_COMPILED_ALIASES.json',index)],[(prefix,root) for root,prefix in builds.items()])
        print(opt,q['bytes'],q['sha256'],flush=True)
    q=archive(a.output,'EXTENDED_DRAINAGE_HISTORY_WINDOWS_SOURCE_RAW_ARCHIVE',
        [('full-source',a.evidence/'history-windows-source-v1'),('source',a.evidence/'history-windows-current-source-v1')],
        [('provider-PREPARED.json',a.provider/'PREPARED.json')])
    print('SOURCE',q['bytes'],q['sha256'],flush=True)
    directories=[('scope-current',a.evidence/'history-public-scope-v3'),('scope-failed-v1',a.evidence/'history-public-scope-v1'),('scope-failed-v2',a.evidence/'history-public-scope-v2')]
    builds=[('late-refusal-generated-source',work/'extended-history-O0-v1/scope-v2/compatibility')]
    for opt,case,h in [('O0','water',1),('O2','cde',2)]:
        root=a.evidence/f'history-short-{case}-h{h}-{opt}-v1';q=json.loads((root/'RESULT.json').read_text());directories.append(('prototype-'+opt,root));builds.append(('prototype-'+opt+'-build',Path(q['build_root'])))
    q=archive(a.output,'EXTENDED_DRAINAGE_HISTORY_SCOPE_AND_PROTOTYPE_RAW',directories,
        [('ACTUAL_REFUSAL_DECODER_V1.json',a.evidence/'HISTORY_ACTUAL_REFUSAL_DECODER_V1.json')],builds)
    print('SCOPE_AND_PROTOTYPE',q['bytes'],q['sha256'],flush=True)


if __name__=='__main__':main()
