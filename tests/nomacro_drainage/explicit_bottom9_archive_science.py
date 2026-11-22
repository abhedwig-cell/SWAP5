"""Replay actual paired-boundary evidence through explicit immutable ZIP locations."""
import argparse,fnmatch,hashlib,io,json,tarfile,zipfile
from contextlib import ExitStack
from pathlib import Path,PurePosixPath
from analytical_hydraulic_archives import Archive,SHA
from frost_cde_drainage_science import View,Bytes
from explicit_bottom9_source_inverse import ROOT,CORE,git,complete_inverse
from explicit_bottom9_composition_science import audit as composition
from explicit_bottom9_drain_science import audit as drainage
from explicit_bottom9_compiled_postimage import compare as binary

PRODUCER='8c60c07248172b7b6cb7032f40b141e8fc2363f0'
ARTIFACTS={'O0':(14736513219,17969175,'eef2f2930ad3edf7dd440a77817891082c7b6e9277c29c1904407ff12ca3c336'),
 'O2':(14735964954,18100557,'73ee45d2d9c2e971fab5dd5d2c989d498185d1c6b42a7240d99c3f0199fb02c1')}
CASES=('water-pressure-step','cde-distributed-drain','age-pressure-subdaily')


class ReadView(View):
    def __truediv__(self,name):return ReadView(self.store,self.path+'/'+str(name))
    @property
    def suffix(self):return PurePosixPath(self.path).suffix
    @property
    def stem(self):return PurePosixPath(self.path).stem
    def relative_to(self,root):
        assert self.store is root.store
        return PurePosixPath(self.path).relative_to(PurePosixPath(root.path))
    def glob(self,pattern):return [ReadView(self.store,p.path) for p in super().glob(pattern)]
    def rglob(self,pattern):
        prefix=self.path+'/'
        return [ReadView(self.store,n) for n in sorted(self.store.names) if n.startswith(prefix) and fnmatch.fnmatch(PurePosixPath(n).name,pattern)]


def source(store,stack):
    captured=json.loads(store.get('source/RESULT.json'));raw=store.get('source/actual-producer-source.zip')
    assert captured['producer_head']==PRODUCER and len(raw)==captured['bytes'] and SHA(raw)==captured['sha256']
    assert not git('diff',CORE,PRODUCER,'--','app','src','tools/solute','tools/vq','reference')
    cap=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)))
    expected={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',PRODUCER).decode().splitlines()}
    def check(name,value,item):
        assert len(value)==item['bytes'] and SHA(value)==item['sha256']
        blob=lambda v:hashlib.sha1(b'blob '+str(len(v)).encode()+b'\0'+v).hexdigest()
        assert item['git_blob']==expected[name] and expected[name] in (blob(value),blob(value.replace(b'\r\n',b'\n')))
    absent={name for name,item in captured['members'].items() if item.get('checkout')=='ABSENT'}
    assert all(name.startswith('reference/swap-4.3.1/') for name in absent)
    assert set(cap.namelist())==set(captured['members'])-absent
    for name,item in captured['members'].items():
        if name in absent:assert item==dict(git_blob=expected[name],checkout='ABSENT')
        else:check(name,cap.read(name),item)
    ctl=json.loads(store.get('controller-source.json'));raw=store.get('controller-source.tar')
    assert ctl['producer_head']==PRODUCER and len(raw)==ctl['bytes'] and SHA(raw)==ctl['sha256']
    tar=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)))
    assert {m.name for m in tar.getmembers()}==set(ctl['members'])
    for name,item in ctl['members'].items():check(name,tar.extractfile(name).read(),item)
    workflow=git('show',PRODUCER+':.github/workflows/nomacro-explicit-bottom9.yml')
    assert store.get('actual-workflow.yml')==workflow
    assert store.get('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
    original=cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP')
    prepared=json.loads(store.get('provider-PREPARED.json'))
    assert SHA(original)==prepared['source_archives']['SWAP.ZIP']=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
    for name,digest in prepared['provider_files'].items():
        if name.startswith('build/'):assert SHA(store.get('original-provider-build/'+name[len('build/'):]))==digest
    return original,dict(producer=PRODUCER,source_sha256=captured['sha256'],controller_sha256=ctl['sha256'],source_members=len(captured['members']),controller_members=len(ctl['members']),toolchain=prepared['toolchain'],original_SWAP_ZIP_sha256=SHA(original))


class Reference:
    """Provider build and byte-identical original distribution in source capsule."""
    def __init__(self,store,original):self.store,self.original=store,original
    def __truediv__(self,name):
        if name.startswith('build/'):
            assert '..' not in PurePosixPath(name).parts
            return ReadView(self.store,'original-provider-build/'+name[len('build/'):])
        assert name=='distribution/SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP'
        return ReadView(Bytes({'SWAP.ZIP':self.original}),'SWAP.ZIP')


def seal(proof,opt):
    name='EXPLICIT_BOTTOM9_UBUNTU_'+opt+'_RAW_V1';path=proof/(name+'.zip');artifact,size,digest=ARTIFACTS[opt]
    assert path.stat().st_size==size and SHA(path.read_bytes())==digest
    with zipfile.ZipFile(path) as z:
        assert len(z.namelist())==len(set(z.namelist())) and all(not n.endswith('/') for n in z.namelist())
        members={n:dict(bytes=len(z.read(n)),sha256=SHA(z.read(n))) for n in z.namelist()}
    record=dict(status='ACTUAL_ORIGINAL_TARGETED_UBUNTU_EXPLICIT9_RAW_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,actual_artifact=artifact,actual_workflow_run=44978763402,actual_producer=PRODUCER,optimization=opt,cases=list(CASES),short35_contexts=3,native_checkpoints=21,exact_cold_windows=9,compiler_postimages=3,canonical_admission=False)
    target=proof/(name+'.json');text=json.dumps(record,indent=2)+'\n'
    if target.exists():assert json.loads(target.read_text())==record
    else:target.write_text(text,encoding='utf-8')


def ubuntu(proof,opt):
    complete_inverse()
    with ExitStack() as stack:
        store=Archive(proof,'EXPLICIT_BOTTOM9_UBUNTU_'+opt+'_RAW_V1',stack)
        assert (store.record['actual_artifact'],store.record['bytes'],store.record['sha256'])==ARTIFACTS[opt]
        original,provenance=source(store,stack);reference=Reference(store,original)
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
        def build(actual):
            item=projection[actual];view=ReadView(store,item['archive_prefix'])
            assert SHA((view/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
            return view
        results=[]
        for case in CASES:
            label='explicit-bottom9-'+case+'-'+opt+'-short';primary=ReadView(store,label)
            q=json.loads((primary/'RESULT.json').read_text());drain=case=='cde-distributed-drain'
            assert q['case']==case and q['optimization']==opt and q['source']==PRODUCER
            post=ReadView(store,label+('-initial1-counterpart' if drain else '-initial2-postimage'));p=json.loads((post/'RESULT.json').read_text())
            actual=p['reference_profile'] if drain else p['initial1_profile']
            assert actual=='/home/runner/work/_temp/proof/'+label
            assert q['input_root']=='/home/runner/work/_temp/proof/inputs/'+case+('-initial2' if drain else '-initial1')
            assert p['input_root']=='/home/runner/work/_temp/proof/inputs/'+case+('-initial1' if drain else '-initial2')
            locations=dict(inputs=ReadView(store,q['input_root'].split('/proof/',1)[1]),build=build(q['build_root']),counter=build(p['build_root']),counter_inputs=ReadView(store,p['input_root'].split('/proof/',1)[1]),original_profile_path=actual)
            observed=(drainage if drain else composition)(primary,reference,post,locations)
            assert observed==json.loads(store.get(label+'-INDEPENDENT.json')),'Actual sealed independent observations changed: '+label
            compiled=binary(locations['counter'],locations['build']) if drain else binary(locations['build'],locations['counter'])
            assert compiled==(p['actual_complete_compiled_bytes'] if drain else json.loads(store.get(label+'-ACTUAL-COMPILED.json')))
            results.append(dict(case=case,optimization=opt,science=observed,actual_compiled_binary=compiled))
            print('ACTUAL_CENTRAL_ARCHIVE_SCIENCE_AND_COMPILED_BYTES_PASS',case,opt,flush=True)
        return dict(status='ACTUAL_THREE_LINUX_EXPLICIT9_CENTRAL_ARCHIVE_SCIENCE_NATIVE_COLD_COMPILED_BYTES_REPLAY_PASS_NOT_ADMITTED',source=provenance,contexts=results,compiler_executions=0,model_executions=0,producer_metadata_rewritten=False,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--seal',action='store_true');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if a.seal:seal(a.proof,a.optimization)
    result=ubuntu(a.proof,a.optimization)
    with a.output.open('x',encoding='utf-8') as out:json.dump(result,out,indent=2);out.write('\n')
    print(result['status'],a.optimization,flush=True)
