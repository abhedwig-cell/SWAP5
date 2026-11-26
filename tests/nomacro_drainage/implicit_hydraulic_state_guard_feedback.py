"""Original zero-day reader and genuine-head compiler proof for inactive ALFAW."""
import argparse,hashlib,io,json,os,re,shutil,subprocess,sys,time,zipfile
from pathlib import Path

R=Path(__file__).resolve().parents[2]
P='integration/f-ci/nomacro-complete01/'
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
ARCHIVE='ORDINARY_IMPLICIT_POND_UBUNTU_FOLLOWUP_O0_RAW_ARCHIVE'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
git=lambda *args:subprocess.check_output(['git',*args],cwd=R)


def remove_inactive_column(raw):
    lines=raw.splitlines(keepends=True)
    indices=[i for i,line in enumerate(lines) if re.match(rb'^[ \t]*ORES[ \t]+OSAT\b',line,re.I)]
    assert len(indices)==1
    first=indices[0];columns=lines[first].split();index=columns.index(b'ALFAW')
    def remove(line):
        tokens=list(re.finditer(rb'\S+',line));assert len(tokens)==len(columns)
        begin=tokens[index].start() if index+1<len(tokens) else tokens[index-1].end()
        end=tokens[index+1].start() if index+1<len(tokens) else tokens[index].end()
        after=line[:begin]+line[end:]
        assert after.split()==[m.group() for j,m in enumerate(tokens) if j!=index]
        return after
    before_columns=list(columns);lines[first]=remove(lines[first]);rows=[]
    for i in range(first+1,len(lines)):
        if lines[i].lstrip().startswith(b'*'):break
        if not lines[i].strip():continue
        before=lines[i].split();assert len(before)==len(columns)
        after=remove(lines[i]);values=dict(zip(before_columns,before));values.pop(b'ALFAW')
        assert values==dict(zip(lines[first].split(),after.split()))
        rows.append(dict(before=before,after=after.split()));lines[i]=after
    assert rows
    return b''.join(lines),dict(removed_column='ALFAW',all_other_tokens_and_line_endings_preserved=True,rows=len(rows))


def snapshot_inputs(root):
    return {p.relative_to(root).as_posix():SHA(p.read_bytes()) for p in root.rglob('*') if p.is_file()}


def public_reader(root,expected_head):
    code="""import json,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'app/hybrid_water'))
from experimental_project import load
q=dict(actual_head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),compiler_executions=0,model_executions=0)
try:
 p=load(Path(sys.argv[1]),original_output=True);q.update(status='ACTUAL_PUBLIC_INPUT_ACCEPTED',nodes=p.nodes)
except ValueError as e:q.update(status='ACTUAL_PUBLIC_INPUT_REFUSED',error=repr(e))
print(json.dumps(q))
"""
    result=subprocess.run([sys.executable,'-B','-c',code,str(root)],cwd=R,capture_output=True,check=True)
    assert not result.stderr;q=json.loads(result.stdout);assert q['actual_head']==expected_head
    return q


def build(root,inputs,provider,opt,folder,expected_head):
    assert git('rev-parse','HEAD').decode().strip()==expected_head
    command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--reference-work',str(provider),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(root)]
    started=time.perf_counter()
    with (folder/('build-'+opt+'.stdout')).open('xb') as out,(folder/('build-'+opt+'.stderr')).open('xb') as err:
        result=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
    result.check_returncode();meta=json.loads((root/'BUILD.json').read_text())
    return dict(actual_compiler_source=expected_head,command=command,seconds=time.perf_counter()-started,actual_BUILD_sha256=SHA((root/'BUILD.json').read_bytes()),meta=meta)


def main():
    p=argparse.ArgumentParser()
    for name in ['output','build-o0','build-o2','reference-work','original-probe']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();head=git('rev-parse','HEAD').decode().strip();branch=git('branch','--show-current').decode().strip()
    assert branch=='codex/nomacro-implicit-hydraulic-state11' and not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    assert git('diff','--name-only',BASE,head,'--','app').decode().splitlines()==['app/hybrid_water/implicit_conductivity.py']
    assert a.output.is_dir() and not any(a.output.iterdir())
    record=dict(status='RUNNING_INACTIVE_ALFAW_REAL_READER_AND_COMPILER_FEEDBACK',actual_controller_source=head,actual_parent=BASE,controller_sha256=SHA(Path(__file__).read_bytes()),model_executions=0,model_days=0,public_build_commands=0,source_or_namespace_projected=False,contexts=[])
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
    save()
    try:
        descriptor=json.loads(git('show',BASE+':'+P+ARCHIVE+'.json'));raw=git('show',BASE+':'+P+descriptor['archive'])
        assert len(raw)==descriptor['bytes'] and SHA(raw)==descriptor['sha256'] and descriptor['actual_job_conclusion']=='success'
        record['original_input_authority']=dict(manifest=ARCHIVE+'.json',retained_git_source=BASE,archive_sha256=descriptor['sha256'],actual_scientific_producer=descriptor['actual_producer_source'])
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            for kind,prefix in [('hys0','ordinary-matrix/water-plate/input/'),('hys1','ordinary-matrix/cde-head-history1/input/')]:
                for variant in ['with-alfaw','without-alfaw']:
                    folder=a.output/(kind+'-'+variant);folder.mkdir();inputs=folder/'inputs';inputs.mkdir()
                    for name,item in descriptor['members'].items():
                        if not name.startswith(prefix):continue
                        value=z.read(name);assert len(value)==item['bytes'] and SHA(value)==item['sha256']
                        target=inputs/name[len(prefix):];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(value)
                    before=snapshot_inputs(inputs)
                    if variant=='without-alfaw':
                        path=inputs/'swap.swp';after,proof=remove_inactive_column(path.read_bytes());path.write_bytes(after)
                        assert {n for n in before if before[n]!=snapshot_inputs(inputs)[n]}=={'swap.swp'}
                    else:proof='ORIGINAL_IMMUTABLE_INPUT_BYTES_UNCHANGED'
                    record['contexts'].append(dict(kind=kind,variant=variant,folder=str(folder),input_root=str(inputs),input_sha256=snapshot_inputs(inputs),input_edit=proof))
        metadata=json.loads((a.original_probe.parent/'BUILD_DIAGNOSTIC.json').read_text());compiler=Path('C:/msys64/ucrt64/bin/gfortran.exe')
        assert SHA(compiler.read_bytes())==metadata['compiler_sha256']=='d818d364c3f0a422fc195f80539554d4ea38fdcd719046771233dbac294bc371'
        for name,digest in metadata['original_objects'].items():assert SHA((a.reference_work/'build/swap-obj'/name).read_bytes())==digest
        assert SHA((a.reference_work/'build/ttutil-obj/libttutil.a').read_bytes())==metadata['original_library_sha256']
        record['original_probe']=dict(actual_controller_source=metadata['actual_controller_source'],driver_sha256=SHA((a.original_probe.parent/'probe.f90').read_bytes()),executable_sha256=SHA(a.original_probe.read_bytes()),compiler_sha256=metadata['compiler_sha256'],original_diagnostic_label=metadata['mixed_compiler_diagnostic'],all_current_provider_objects_freshly_matched=True,recompiled=False,scope='ReadSwap acceptance only; the retained immutable probe later intentionally refuses SWDRA1 before any model day')
        for item in record['contexts']:
            folder=Path(item['folder']);worker=folder/'original-reader';shutil.copytree(Path(item['input_root']),worker)
            with (folder/'original-reader.stdout').open('xb') as out,(folder/'original-reader.stderr').open('xb') as err:
                run=subprocess.run([str(a.original_probe)],cwd=worker,stdout=out,stderr=err,timeout=45)
            stdout=(folder/'original-reader.stdout').read_bytes();accepted=b'ORIGINAL_INIT_PHASE AFTER_READSWAP' in stdout
            assert accepted==(item['kind']=='hys0' or item['variant']=='with-alfaw')
            assert not list(worker.rglob('accepted-*.zip')) and b'HYBRID_DAY_RETURN' not in stdout
            if accepted:assert b'Unexpected drainage' in (folder/'original-reader.stderr').read_bytes()
            item['original_readswap']=dict(accepted=accepted,returncode=run.returncode,stdout_sha256=SHA(stdout),stderr_sha256=SHA((folder/'original-reader.stderr').read_bytes()),full_initialization_PASS_claimed=False,model_days=0);save()
        subprocess.run(['git','switch','--detach',BASE],cwd=R,check=True)
        for item in record['contexts']:
            item['original_public']=public_reader(Path(item['input_root']),BASE)
            assert (item['original_public']['status']=='ACTUAL_PUBLIC_INPUT_ACCEPTED')==(item['variant']=='with-alfaw')
        parent=next(i for i in record['contexts'] if i['kind']=='hys0' and i['variant']=='with-alfaw')
        for opt,root in [('O0',a.build_o0),('O2',a.build_o2)]:
            parent.setdefault('builds',{})[opt]=build(root/'old-baseline/bundle',Path(parent['input_root']),a.reference_work,opt,Path(parent['folder']),BASE);record['public_build_commands']+=1;save()
        subprocess.run(['git','switch',branch],cwd=R,check=True);assert git('rev-parse','HEAD').decode().strip()==head
        for item in record['contexts']:
            item['current_public']=public_reader(Path(item['input_root']),head)
            assert (item['current_public']['status']=='ACTUAL_PUBLIC_INPUT_ACCEPTED')==(item['kind']=='hys0' or item['variant']=='with-alfaw')
        current=next(i for i in record['contexts'] if i['kind']=='hys0' and i['variant']=='without-alfaw');postimages=[]
        for opt,root in [('O0',a.build_o0),('O2',a.build_o2)]:
            observation=build(root/'current-noalfaw/bundle',Path(current['input_root']),a.reference_work,opt,Path(current['folder']),head);current.setdefault('builds',{})[opt]=observation;record['public_build_commands']+=1
            old=root/'old-baseline/bundle';new=root/'current-noalfaw/bundle';before=parent['builds'][opt]['meta'];after=observation['meta']
            for key in ['compiler','compiler_sha256','target','donor_flags','kernel_flags','donor_generated','donor_objects','donor_modules','ttutil_modules','ttutil_library']:assert before['identity'][key]==after['identity'][key],key
            for name,digest in before['identity']['donor_generated'].items():assert (old/name).read_bytes()==(new/name).read_bytes() and SHA((new/name).read_bytes())==digest
            names={p.name for p in old.glob('*.o')};assert names=={p.name for p in new.glob('*.o')} and names;objects=[]
            for name in sorted(names):
                value=(new/name).read_bytes();assert value==(old/name).read_bytes();objects.append(dict(file=name,bytes=len(value),sha256=SHA(value)))
            postimages.append(dict(optimization=opt,actual_original_source=BASE,actual_current_source=head,whole_objects=objects,object_bytes_normalized=False,model_period_replayed=False));save()
        record.update(status='ORIGINAL_OPTIONAL_ALFAW_PUBLIC_GUARD_REPAIRED_REAL_READER_AND_O0_O2_COMPLETE_GENERATED_AND_WHOLE_OBJECT_POSTIMAGES_PASS_NO_MODEL_REPLAY',postimages=postimages,new_scientific_contexts=0,canonical_admission=False)
    except Exception as error:record.update(status='FAILED_INACTIVE_ALFAW_FEEDBACK_NOT_QUALIFIED',error=repr(error));raise
    finally:
        if not git('status','--porcelain=v1','--untracked-files=all','--ignored') and git('rev-parse','HEAD').decode().strip()!=head:subprocess.run(['git','switch',branch],cwd=R,check=True)
        save()
    print(record['status'],flush=True)


if __name__=='__main__':main()
