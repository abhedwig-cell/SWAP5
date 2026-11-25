"""Fresh sealed Windows postimages and actual compiler/native controls; no runs."""
import argparse,hashlib,io,json,subprocess,zipfile
from contextlib import ExitStack
from frost_history_state_archives import R,LogicalArchive,Locations,BASE,SHA
from frost_history_state_central import read,rows,compiled,generated,controls,transaction
from ordinary_pond_evidence import physical


def checkpoint(view,day):
    with zipfile.ZipFile(io.BytesIO((view/f'accepted-column-1-day-{day}.zip').read_bytes())) as z:
        q=json.loads(z.read('checkpoint.json'))
        assert all(SHA(z.read(n))==h for n,h in q['files'].items())
        return z.read('macro.bin'),z.read('result.end')


def audit():
    with ExitStack() as stack:
        store=LogicalArchive('FROST_HYSTERESIS_STATE01_WINDOWS_RAW_V1',stack)
        loc=Locations(store,json.loads(store.get('ACTUAL_ARCHIVE_LOCATIONS_V1.json')))
        # Read every physical payload once, including original failures and censored data.
        for name in store.physical.names:store.physical.get(name)
        provenance=json.loads(store.get('SOURCE_CUSTODY_V1.json'));source=[]
        for epoch in provenance['actual_compiler_epochs']:
            commit=store.get('source/'+epoch+'/actual-commit.bin')
            assert hashlib.sha1(b'commit '+str(len(commit)).encode()+b'\0'+commit).hexdigest()==epoch
            tree={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in subprocess.check_output(['git','ls-tree','-r',epoch],cwd=R).decode().splitlines()}
            count=0;prefix='source/'+epoch+'/'
            for name in store.names:
                if not name.startswith(prefix) or name==prefix+'actual-commit.bin':continue
                raw=store.get(name);path=name[len(prefix):]
                assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==tree[path],path
                count+=1
            source.append(dict(actual_compiler=epoch,actual_git_source_blobs=count))
        defaults=[];folder=store.view('profiles/frost-history-state01-same-R-hys2-default-baselines-v1')
        original=read(folder/'RESULT.json');postrun=read(folder/'POSTRUN_COMPARISON_V1.json')
        assert SHA((folder/'RESULT.json').read_bytes())==postrun['original_RESULT_sha256']
        assert original['baseline']==BASE and len(original['builds'])==8 and original['model_periods_executed']==0
        for stem in ('explicit-water','explicit-cde','implicit-water','implicit-cde'):
            pair={x['phase']:x for x in original['builds'] if x['stem']==stem}
            assert set(pair)=={'canonical','current'}
            for phase,item in pair.items():
                assert item['returncode']==item['actual_phase_bundle_validation_returncode']==0
                assert item['actual_compiler_source']==(BASE if phase=='canonical' else original['orchestrator_source'])
                assert (folder/(phase+'-'+stem)/'validate.stdout').read_bytes().strip()==b'ACTUAL_PHASE_BUNDLE_VALIDATED'
                assert not (folder/(phase+'-'+stem)/'validate.stderr').read_bytes()
            left,right=(loc.resolve(pair[p]['build_root']) for p in ('canonical','current'))
            defaults.append(dict(stem=stem,generated=generated(left,right),compiled=compiled(left,right)))
        current=[]
        for kind,hys,opt in [('water',0,'O0'),('water',1,'O2'),('cde',0,'O0'),('cde',1,'O2')]:
            label=f'frost-history-state01-current-explicit-{kind}-hys{hys}-{opt}-v1';folder=store.view('profiles/'+label);q=read(folder/'RESULT.json');profile=loc.resolve(q['original_profile']);old=read(profile/'RESULT.json');left,right=loc.resolve(old['build_root']),loc.resolve(q['actual_build_root'])
            assert q['full35_periods_replayed']==0 and q['exact_original_physical_prefix']
            assert physical(rows(folder/'prefix6'))==physical(rows(profile/'trajectory')[:6])
            for day in (2,4):assert checkpoint(folder/'prefix6',day)==checkpoint(profile/'trajectory',day)
            current.append(dict(context=label,generated=generated(left,right),compiled=compiled(left,right),native_prefix_days=[2,4]))
        initial=[]
        for implicit in ('explicit','implicit'):
            for kind in ('water','cde'):
                for hys in (0,1):
                    for opt in ('O0','O2'):
                        profiles=[read(store.view(f'profiles/frost-history-state01-{implicit}-{kind}-hys{hys}-initial{i}-{opt}-v1/RESULT.json')) for i in (1,2)]
                        left,right=[loc.resolve(p['build_root']) for p in profiles]
                        initial.append(dict(mode=implicit,kind=kind,hysteresis=hys,optimization=opt,generated=generated(left,right),compiled=compiled(left,right)))
        native=[]
        for label,profile_label,kind,hys in [('first-implicit-native-transactions-O0','implicit-water-hys0-initial1-O0','water',0),('implicit-cde-hys1-O2-native-transactions','implicit-cde-hys1-initial2-O2','cde',1)]:
            folder=store.view('profiles/frost-history-state01-'+label+'-v1');profile=store.view('profiles/frost-history-state01-'+profile_label+'-v1');meta=read(loc.resolve(read(profile/'RESULT.json')['build_root'])/'BUILD.json')
            native.append(controls(folder,profile,meta,kind,hys,1))
        inherited=read(store.view('profiles/frost-history-state01-inherited-native-representatives-v1/RESULT.json'));refusals=0;transactions=[]
        for item in inherited['contexts']:
            profile=store.view('profiles/'+item['profile']);q=read(profile/'RESULT.json');meta=read(loc.resolve(q['build_root'])/'BUILD.json');kind=q['kind'];hys=0 if kind=='water' else 1
            good=checkpoint(profile/'trajectory',4)[0];assert len(item['checks'])==(39 if kind=='water' else 44)
            for attack in item['checks']:
                target=store.view('profiles/frost-history-state01-inherited-native-representatives-v1/'+item['profile']+'/'+attack['attack'])
                stderr=target.rglob('donor.stderr');stdout=target.rglob('donor.stdout');assert len(stderr)==len(stdout)==1
                assert b'ERROR STOP' in stderr[0].read_bytes() and b'HYBRID_READY' not in stdout[0].read_bytes() and b'HYBRID_DAY_RETURN' not in stdout[0].read_bytes()
                assert (target/'origin/macro.bin').read_bytes()!=good and not target.rglob('accepted-*.zip');refusals+=1
            folder=store.view('profiles/frost-history-state01-inherited-transactions-v1/'+item['profile'])
            transactions.append(transaction(folder/'external',rows(profile/'trajectory'),meta,kind,hys,0,4))
            assert physical([json.loads(zipfile.ZipFile(io.BytesIO((folder/'recovered/trial-1/accepted-column-1-day-6.zip').read_bytes())).read('checkpoint.json'))['receipt']])==physical([rows(profile/'trajectory')[5]])
        frontend=read(store.view('profiles/frost-history-state01-current-both-frontends-v5/RESULT.json'))
        counts={name:sum(x['status']==name for x in frontend['checks']) for name in {x['status'] for x in frontend['checks']}}
        assert counts==dict(CURRENT_NEW_ROUTE_SELECTED=16,ACTUAL_PUBLIC_FRONTEND_REFUSED_NO_BUILD=46,EXISTING_HYS2_ROUTE_RETAINED=2,ORIGINAL_UNIMPLEMENTED_EXAMINED_KSAT_REFUSED=1)
        assert frontend['compiler_executions']==frontend['model_executions']==0
        return dict(status='FRESH_ALL_WINDOWS_FROST_ACTUAL_SOURCE_DEFAULT_INITIAL_COMPILED_NATIVE_AND_FRONTEND_PRESERVATION_PASS',archive_sha256=store.record['sha256'],physical_payloads=len(store.physical.names),logical_files=len(store.names),actual_source=source,default_hys2_postimages=defaults,current_explicit_postimages=current,initial12_postimages=initial,implicit_controls=native,explicit_native_refusals=refusals,explicit_transactions=transactions,frontend=counts,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();value=audit()
    with open(a.output,'x') as out:json.dump(value,out,indent=2);out.write('\n')
    print(value['status'])
