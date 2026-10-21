"""Exercise the real current owner guard; no physical oracle/assertion replacement."""
import json
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[2]


def main():
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_gash_successor.py'),run_name='temporal_owner_controls')
    source=owner['source']
    source()
    check=owner['diagnostic_source_successors']
    assert len(check())==3
    passed=[]

    def reject(name,action):
        try:action()
        except (ValueError,KeyError):passed.append(name)
        else:raise AssertionError('accepted corruption: '+name)

    read=lambda q:(ROOT/q).read_bytes()
    path='integration/performance/SWAP5-PERF01_STATUS.json'

    def changed_status(change):
        def reader(q):
            if q!=path:return read(q)
            data=json.loads(read(q));change(data)
            return json.dumps(data).encode()
        return reader

    for q in owner['DIAGNOSTIC_TOOLS']:
        reject('diagnostic source drift '+q,lambda q=q:check(lambda p:read(p)+(b'!'if p==q else b'')))
    reject('production flag',lambda:check(changed_status(lambda d:d['temporal_study'].__setitem__('production_changed',True))))
    reject('missing registration',lambda:check(changed_status(lambda d:d['exact_successor']['postimages'].pop(next(iter(owner['DIAGNOSTIC_TOOLS']))))))
    reject('foreign registration hash',lambda:check(changed_status(lambda d:d['exact_successor']['postimages'][next(iter(owner['DIAGNOSTIC_TOOLS']))].__setitem__('sha256','0'*64))))
    reject('native failures relabelled',lambda:check(changed_status(lambda d:d['temporal_study'].__setitem__('retained_native_failures',0))))
    # Exercise source() itself, injecting a committed diff row rather than
    # duplicating its ownership assertion in the test.
    globals_=source.__globals__
    original_git=globals_['git']
    for label,row in [('unregistered tool','A\ttools/performance/unreviewed.py'),
                      ('changed production','M\tsrc/runtime/mod_canonical_interval_runtime.f90')]:
        def injected(*args,row=row):
            text=original_git(*args)
            if args[:2]==('diff','--name-status'):return text+'\n'+row
            return text
        globals_['git']=injected
        try:reject(label,source)
        finally:globals_['git']=original_git
    source()
    print(json.dumps({'status':'EXACT_DIAGNOSTIC_REGISTRATION_PASS','negative_controls':passed,'count':len(passed)},indent=2))


if __name__=='__main__':main()
