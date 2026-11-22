"""Replay only the targeted last-node delta and prove prior42 guard nonselection."""
import argparse,ast,hashlib,io,json,posixpath,tarfile,types,zipfile
from pathlib import Path,PurePosixPath
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView,Reference,source
from explicit_bottom9_last_node_science import audit
from explicit_bottom9_compiled_postimage import compare
from explicit_bottom9_source_inverse import ROOT,CORE,LAST_NODE_CORE,ADAPTER,complete_inverse,blob,norm,git

PORTABLE='e462878f2cac5895b0dbdc9ae90d1276384f0327'
SPECS={'O0':(14739270255,11398511,'5ebf562ee93695e3e1e12406a992840c7a1ab70367e5e3c45769fe0747e2d404'),
 'O2':(14738771899,11442450,'fdefee9162f717faf126361be4c522072cce3bb24e842a9a206b6d9d798aeba8')}


def seal_ubuntu(proof,opt):
    name='EXPLICIT_BOTTOM9_LAST_NODE_UBUNTU_'+opt+'_RAW_V1';path=proof/(name+'.zip');artifact,size,digest=SPECS[opt]
    assert path.stat().st_size==size and SHA(path.read_bytes())==digest
    with zipfile.ZipFile(path) as z:
        assert len(z.namelist())==len(set(z.namelist()))
        members={n:dict(bytes=len(z.read(n)),sha256=SHA(z.read(n))) for n in z.namelist()}
    q=dict(status='ACTUAL_ORIGINAL_TARGETED_UBUNTU_LAST_NODE_WATER_RAW_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,actual_artifact=artifact,actual_run=44983154144,actual_producer=PORTABLE,optimization=opt,new_short35_contexts=1,new_native_checkpoints=7,new_exact_cold_windows=3,new_initial2_compiled_counterparts=1,original_six_linux_periods_replayed=False,canonical_admission=False)
    target=proof/(name+'.json')
    if target.exists():assert json.loads(target.read_text())==q
    else:target.write_text(json.dumps(q,indent=2)+'\n')


def built(store,projection,actual):
    item=projection[actual];path=ReadView(store,item['archive_prefix']);assert SHA((path/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return path


def ubuntu(proof,opt):
    complete_inverse()
    with ExitStack() as stack:
        store=Archive(proof,'EXPLICIT_BOTTOM9_LAST_NODE_UBUNTU_'+opt+'_RAW_V1',stack)
        assert (store.record['actual_artifact'],store.record['bytes'],store.record['sha256'])==SPECS[opt]
        original,provenance=source(store,stack,PORTABLE,LAST_NODE_CORE);reference=Reference(store,original)
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));label='explicit-bottom9-water-last-node-drainage-'+opt+'-short'
        profile=ReadView(store,label);post=ReadView(store,label+'-initial2-postimage');q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text())
        assert q['source']==p['source']==PORTABLE and q['input_admission_core']==LAST_NODE_CORE and q['physical_core']==CORE
        assert p['initial1_profile']=='/home/runner/work/_temp/proof/'+label
        assert q['input_root']=='/home/runner/work/_temp/proof/inputs/water-last-node-drainage-initial1' and p['input_root']=='/home/runner/work/_temp/proof/inputs/water-last-node-drainage-initial2'
        loc=dict(inputs=ReadView(store,'inputs/water-last-node-drainage-initial1'),counter_inputs=ReadView(store,'inputs/water-last-node-drainage-initial2'),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=p['initial1_profile'])
        science=audit(profile,reference,post,loc);assert science==json.loads(store.get(label+'-INDEPENDENT.json'))
        binary=compare(loc['build'],loc['counter']);assert binary==json.loads(store.get(label+'-ACTUAL-COMPILED.json'))
    return dict(status='ACTUAL_TARGETED_LINUX_LAST_NODE_WATER_ORIGINAL_ARCHIVE_SCIENCE_NATIVE_COLD_COMPILED_BYTES_REPLAY_PASS_NOT_ADMITTED',optimization=opt,source=provenance,science=science,actual_compiled=binary,compiler_executions=0,model_executions=0,canonical_admission=False)


def capsule(store,prefix,head,stack,controller=None):
    q=json.loads(store.get(prefix+'/RESULT.json'));raw=store.get(prefix+'/actual-producer-source.zip')
    assert q['producer_head']==head and len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and not git('diff',LAST_NODE_CORE,head,'--','app','src','tools/solute','tools/vq','reference')
    expected={l.split('\t',1)[1]:l.split('\t',1)[0].split()[2] for l in git('ls-tree','-r',head).decode().splitlines()}
    def check(name,value,item):
        assert len(value)==item['bytes'] and SHA(value)==item['sha256'] and item['git_blob']==expected[name]
        obj=lambda v:hashlib.sha1(b'blob '+str(len(v)).encode()+b'\0'+v).hexdigest()
        assert expected[name] in (obj(value),obj(value.replace(b'\r\n',b'\n')))
    z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));absent={n for n,i in q['members'].items() if i.get('checkout')=='ABSENT'}
    assert set(z.namelist())==set(q['members'])-absent
    for name,item in q['members'].items():
        if name in absent:assert item==dict(git_blob=expected[name],checkout='ABSENT')
        else:check(name,z.read(name),item)
    if controller:
        c=json.loads(store.get('observations/'+controller+'.json'));raw=store.get('observations/'+controller+'.tar')
        assert c['producer_head']==head and len(raw)==c['bytes'] and SHA(raw)==c['sha256']
        tar=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)));assert {m.name for m in tar.getmembers()}==set(c['members'])
        for name,item in c['members'].items():check(name,tar.extractfile(name).read(),item)
    return z


def predicate():
    nodes=[n for n in ast.walk(ast.parse(norm((ROOT/ADAPTER).read_bytes()))) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='paired_last_node_water' for t in n.targets)];assert len(nodes)==1
    return compile(ast.Expression(nodes[0].value),'actual-checked-last-node-file-ownership-predicate','eval')


class ControlPath(ReadView):
    def __truediv__(self,name):return ControlPath(self.store,self.path+'/'+str(name))
    def resolve(self):
        # The captured tree was checked for symlinks before preservation. Both
        # sides of the literal predicate use this same explicit archive root.
        return self.store,posixpath.normpath(self.path)


def frontend(store,cap):
    import experimental_project as e
    import prescribed_head_flux_boundary as boundary
    select=types.FunctionType(boundary.selection.__code__,dict(boundary.selection.__globals__,Path=lambda value:value))
    run=predicate();root='reference/swap-4.3.1/projects/';prefixes=[root+n+'/' for n in ('1.hupselbrook','2.grassgrowth','4.salinitystress-04dS')]
    signatures=[e.switches(cap.read(n).decode('cp1252')) for n in cap.namelist() if any(n.startswith(p) and '/' not in n[len(p):] and n.endswith('.dra') for p in prefixes)];assert signatures
    structure=lambda s:{k:v for k,v in s.items() if k!='SWDIVD'}
    record=json.loads(store.get('observations/EXPLICIT_BOTTOM9_LAST_NODE_FRONTEND_CONTROLS_V1.json'));assert len(record['checks'])==9;results=[]
    for item in record['checks']:
        relative=item['input_root'].replace('\\','/').split('/evidence/',1)[1];directory=ControlPath(store,'profiles/'+relative)
        for name,digest in item['input_inventory']:assert SHA((directory/name).read_bytes())==digest
        text=(directory/'swap.swp').read_text(encoding='cp1252');e.check_paths(text,'swap.swp');selected=e.switches(text);pair=select(directory,True);new_scope=pair is not None
        for view in directory.rglob('*.dra'):
            path=ControlPath(store,view.path);body=path.read_text(encoding='cp1252');e.check_paths(body,path.name);sig=e.switches(body)
            if sig in signatures:continue
            owned=eval(run,dict(paired_boundary=pair,selected=selected,sig=sig,path=path,directory=directory,text=text,one=e.one))
            if not owned or sig.get('SWDIVD') not in (0,1) or structure(sig) not in list(map(structure,signatures)):new_scope=False
        assert new_scope==(item['status']=='ACTUAL_SELECTED_DRAINAGE_FILE_IN_SUBFOLDER_LOADED'),item['label']
        results.append(dict(label=item['label'],actual_new_path_and_unchanged_structure_admission=new_scope,actual_input_inventory_verified=True,original_public_observation=item['status']))
    assert sum(i['actual_new_path_and_unchanged_structure_admission'] for i in results)==1
    return dict(status='ARCHIVED_SELECTED_DRAINAGE_SUBFOLDER_AND_EIGHT_HARD_BOUNDARIES_LITERAL_GUARD_REPLAY_PASS',checks=results,compiler_executions=0,model_executions=0)


def inherited42(proof):
    complete_inverse();run=predicate();observed=[]
    with ExitStack() as stack:
        for name in ('EXPLICIT_BOTTOM9_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_UBUNTU_O0_RAW_V1','EXPLICIT_BOTTOM9_UBUNTU_O2_RAW_V1'):
            store=Archive(proof,name,stack)
            if 'WINDOWS' in name:roles=store.record['roles']+store.record['water_controls']
            else:
                opt=store.record['optimization'];roles=[dict(profile='explicit-bottom9-'+c+'-'+opt+'-short',inputs='inputs/'+c+('-initial2' if c=='cde-distributed-drain' else '-initial1')) for c in ('water-pressure-step','cde-distributed-drain','age-pressure-subdaily')]
            import experimental_project as e
            for role in roles:
                q=json.loads(store.get(role['profile']+'/RESULT.json'));prefix=role['inputs'];selected=e.switches(store.get(prefix+'/swap.swp').decode('cp1252'));sig=e.switches(store.get(prefix+'/swap.dra').decode('cp1252'))
                assert eval(run,dict(paired_boundary={},selected=selected,sig=sig)) is False
                inventory=q['input_inventory'];pairs=inventory.items() if isinstance(inventory,dict) else inventory
                for file,digest in pairs:assert SHA(store.get(prefix+'/'+file))==digest
                observed.append(dict(archive=name,profile=role['profile'],original_producer=q['source'],new_incoming_guard_selected=False,actual_input_bytes_verified=True))
    assert len(observed)==42
    return dict(status='ALL42_ACTUAL_PRIOR_ARCHIVED_CONTEXTS_UNCHANGED_UNDER_LITERAL_NEW_GUARD_NONSELECTION_AND_WHOLE_SOURCE_INVERSE',contexts=42,observations=observed,compiler_executions=0,model_executions=0,original_identities_rewritten=False)


def windows(proof):
    complete_inverse()
    with ExitStack() as stack:
        store=Archive(proof,'EXPLICIT_BOTTOM9_LAST_NODE_WINDOWS_RAW_V1',stack);parent=Archive(proof,'EXPLICIT_BOTTOM9_WINDOWS_RAW_V1',stack);provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
        assert provider.record['sha256']=='804b6c36afe0bbac5a84dd84c289a864f3ef0874b739fb9dbc15539c17ad903a'
        links=json.loads(store.get('PARENT_CENTRAL_RAW_LINKS_V1.json'));assert links['EXPLICIT_BOTTOM9_WINDOWS_RAW_V1']['sha256']==parent.record['sha256']
        original=None;latest=None
        for suffix,head,control in [('3183-v1','31837609d478a2d55781b30df76deb03fd20a8f1','explicit-bottom9-last-node-controller-3183-v1'),('6ce7-v2','6ce72513c589c3a701530bfcaddf9d26e0b4e22b','explicit-bottom9-last-node-controller-6ce7-v2')]:
            cap=capsule(store,'profiles/explicit-bottom9-last-node-actual-source-'+suffix,head,stack,control);value=cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP')
            assert SHA(value)=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
            if original is not None:assert original==value
            original=value;latest=cap
        front=frontend(store,latest);reference=Reference(provider,original);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));observed=[]
        assert len(store.record['roles'])==2
        for role in store.record['roles']:
            profile=ReadView(store,role['profile']);post=ReadView(store,role['postimage']);q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text())
            assert role['actual_producer']==q['source'] and role['inputs_archive']=='EXPLICIT_BOTTOM9_WINDOWS_RAW_V1'
            assert 'profiles/'+q['input_root'].replace('\\','/').split('/evidence/',1)[1]==role['inputs'] and 'profiles/'+p['input_root'].replace('\\','/').split('/evidence/',1)[1]==role['counter_inputs']
            loc=dict(inputs=ReadView(parent,role['inputs']),counter_inputs=ReadView(parent,role['counter_inputs']),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=role['original_profile_path'])
            science=audit(profile,reference,post,loc);assert science==json.loads(store.get(role['independent']))
            actual=compare(loc['build'],loc['counter']);assert actual==json.loads(store.get(role['actual_compiled']))
            observed.append(dict(profile=role['profile'],science=science,actual_compiled=actual));print('ACTUAL_CENTRAL_WINDOWS_LAST_NODE_WATER_SCIENCE_NATIVE_COLD_COMPILED_PASS',q['optimization'],flush=True)
        diagnostic=json.loads(store.get('observations/EXPLICIT_BOTTOM9_LAST_NODE_O0_OBSERVER_DIAGNOSTIC_V1.json'));assert diagnostic['independent_reader_V1_success_claimed'] is False and diagnostic['mass_or_convergence_limits_changed'] is False
    return dict(status='ACTUAL_TWO_WINDOWS_LAST_NODE_WATER_AND_LITERAL_FRONTEND_RAW_NATIVE_COLD_COMPILED_CENTRAL_REPLAY_PASS_NOT_ADMITTED',contexts=observed,frontend=front,failed_exact_zero_observer_preserved=True,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--optimization',choices=('O0','O2'));p.add_argument('--seal',action='store_true');p.add_argument('--inherited42',action='store_true');p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if a.seal:assert a.optimization;seal_ubuntu(a.proof,a.optimization)
    q=inherited42(a.proof) if a.inherited42 else ubuntu(a.proof,a.optimization) if a.optimization else windows(a.proof)
    with a.output.open('x') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
