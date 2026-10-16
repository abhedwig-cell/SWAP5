#!/usr/bin/env python3
"""Verify bounded owner-composition evidence; never grants canonical admission."""
from pathlib import Path
import argparse
import copy
import hashlib
import json

FLAGS=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']


def verify(results,inputs,root,directory):
    if results.get('status')!='PASS':raise ValueError('terminal PASS absent')
    expected={(opt,name,moisture,mode) for opt in (0,2) for name in ('weather','daily_demand','raintb')
              for moisture in (('neutral','dry','hydraulic') if name=='weather' else ('neutral',))
              for mode in ('continuous','restart')}
    rows=results['results'];keys=[(r['opt'],r['driver'],r['moisture'],r['mode']) for r in rows]
    if len(keys)!=20 or set(keys)!=expected:raise ValueError('complete distinct20-case matrix absent')
    hashes={key:row['stdout_sha256'] for key,row in zip(keys,rows)}
    for key,row in zip(keys,rows):
        if row['returncode']!=0:raise ValueError('failed native case')
        opt,name,moisture,mode=key
        if hashes[key]!=hashes[(2-opt,name,moisture,mode)]:raise ValueError('O0/O2 drift')
        if hashes[key]!=hashes[(opt,name,moisture,'restart' if mode=='continuous' else 'continuous')]:raise ValueError('continuation drift')
    if inputs['flags']!=FLAGS:raise ValueError('incumbent compiler flags changed')
    if inputs['inputs']!=results['source_inputs'] or inputs['generated']!=results['generated_inputs']:raise ValueError('source manifest drift')
    for path,digest in results['source_inputs'].items():
        if hashlib.sha256((root/path).read_bytes()).hexdigest()!=digest:raise ValueError('current dependency drift: '+path)
    events=results['events']
    if any(e['returncode']!=0 for e in events):raise ValueError('failed compiler/native/fixture request')
    commands=[e['command'] for e in events]
    compiles=[a for a in commands if '-c' in a and '-o' in a]
    links=[a for a in commands if '-c' not in a and '-o' in a]
    natives=[a for a in commands if Path(a[0]).name in ('test-weather','test-daily_demand','test-raintb')]
    if len(compiles)!=464 or len(links)!=6 or len(natives)!=20:raise ValueError('unexpected compile/link/native coverage')
    for index,event in enumerate(events):
        command=event['command'];exe=Path(command[0])
        if exe.name not in ('test-weather','test-daily_demand','test-raintb'):continue
        name=exe.name.removeprefix('test-');mode=command[-2];moisture=command[-1]
        opt=int(exe.parent.name.removeprefix('o'))
        stdout=directory/f'{index:05d}-native-{name}-{moisture}-{mode}.stdout'
        digest=hashlib.sha256(stdout.read_bytes()).hexdigest()
        if digest!=event['stdout_sha256'] or digest!=hashes[(opt,name,moisture,mode)]:raise ValueError('native raw-output drift')
    for command in compiles+links:
        if command[1:1+len(FLAGS)]!=FLAGS:raise ValueError('actual compiler flags changed')
    for opt in (0,2):
        sources=[a[a.index('-c')+1] for a in compiles if f'-O{opt}' in a]
        if len(sources)!=232 or len(set(sources))!=232:raise ValueError('missing or duplicate compilation')
    return {'claim':'OWNER_COMPOSITION_ONLY_FULL_ADMISSION_PENDING','cases':len(rows),'compile_units':len(compiles),'links':len(links),'native_runs':len(natives)}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory');parser.add_argument('--negative-controls',action='store_true');args=parser.parse_args()
    directory=Path(args.directory).resolve();root=Path(__file__).resolve().parents[2]
    results=json.loads((directory/'RESULTS.json').read_text());inputs=json.loads((directory/'INPUTS.json').read_text())
    receipt=verify(results,inputs,root,directory)
    if args.negative_controls:
        negatives={}
        for name in ['partial','duplicate','failed','o2-drift','flags','source-manifest','compile-removal']:
            altered=copy.deepcopy(results);metadata=copy.deepcopy(inputs)
            if name=='partial':altered['results'].pop()
            if name=='duplicate':altered['results'][-1]=copy.deepcopy(altered['results'][0])
            if name=='failed':altered['results'][0]['returncode']=1
            if name=='o2-drift':altered['results'][0]['stdout_sha256']='0'*64
            if name=='flags':metadata['flags'].remove('-fcheck=all')
            if name=='source-manifest':metadata['inputs'][next(iter(metadata['inputs']))]='0'*64
            if name=='compile-removal':altered['events']=[e for e in altered['events'] if '-c' not in e['command']]
            try:verify(altered,metadata,root,directory)
            except ValueError as error:negatives[name]=str(error)
            else:raise ValueError('bad evidence accepted: '+name)
        receipt['negative_controls']=negatives
    (directory/'VERIFIED.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt))

if __name__=='__main__':main()
