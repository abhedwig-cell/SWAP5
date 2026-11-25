"""Seal original Windows evidence once, with explicit content-addressed storage."""
import argparse,hashlib,io,json,subprocess,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'
COMPILER='c505f2d8f34bff737b61915c4bca3d2a9b44a35d'
P=R/'integration/f-ci/nomacro-complete01'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def main():
    p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);a=p.parse_args();E=a.evidence
    git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
    head=git('rev-parse','HEAD').decode().strip();assert not git('diff',COMPILER,'HEAD','--','app','src','tools','reference')
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    for name in ('frost-history-state01-windows-batch-v1','frost-history-state01-implicit-windows-batch-v1'):
        q=json.loads((E/name/'RESULT.json').read_text());assert len(q['contexts'])==16 and q['status'].startswith('SIXTEEN_WINDOWS_')
    default=json.loads((E/'frost-history-state01-same-R-hys2-default-baselines-v1/POSTRUN_COMPARISON_V1.json').read_text());assert len(default['comparisons'])==4 and default['status'].startswith('FOUR_GENUINE')
    state=json.loads(Path('C:/Users/Veldh012/.codex/storage/swap5/state.json').read_text());resources=[item for item in state['resources'].values() if item['task']==TASK and item['kind']=='build' and Path(item['path']).name.startswith('frost-history-state01-') and item['status']!='deleted'];assert len(resources)==44
    logical={};objects={};locations={};epochs=set();counter=0
    def add(name,raw):
        assert name not in logical;digest=SHA(raw);logical[name]=dict(bytes=len(raw),sha256=digest);objects.setdefault(digest,raw)
    def folder(root,prefix):
        nonlocal counter
        assert not root.is_symlink();locations[str(root)]=dict(prefix=prefix)
        for path in sorted(root.rglob('*')):
            if not path.is_file():continue
            assert not path.is_symlink();add(prefix+'/'+path.relative_to(root).as_posix(),path.read_bytes());counter+=1
        print('PRESERVED',prefix,counter,flush=True)
    for root in sorted(E.glob('frost-history-state01-*')):
        if root.is_dir():folder(root,'profiles/'+root.name)
        elif root.is_file():add('aux/'+root.name,root.read_bytes())
    for path in sorted(E.glob('FROST_HYSTERESIS_STATE01*')):
        if not path.is_file() or path.suffix not in ('.json','.log'):continue
        if '_ALL_MEMBER_READBACK_' in path.name:continue
        add('aux/'+path.name,path.read_bytes())
    for item in resources:
        root=Path(item['path']);assert root.is_dir();folder(root,'compiled/'+root.name);epochs.add(item['source_ref'])
    # Every original source epoch is a real Git object, never a relabelled HEAD.
    domains=('app','src','tools/solute','tools/vq','tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','reference/swap-4.3.1/patches','reference/swap-4.3.1/frost-corrections','reference/swap-4.3.1/hydraulic-corrections')
    process=subprocess.Popen(['git','cat-file','--batch'],cwd=R,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    try:
        cache={}
        def blob(sha,kind):
            if sha in cache:return cache[sha]
            process.stdin.write((sha+'\n').encode());process.stdin.flush();header=process.stdout.readline().decode().split();assert header[:2]==[sha,kind];raw=process.stdout.read(int(header[2]));assert len(raw)==int(header[2]) and process.stdout.read(1)==b'\n';assert hashlib.sha1(kind.encode()+b' '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==sha;cache[sha]=raw;return raw
        for epoch in sorted(epochs):
            add('source/'+epoch+'/actual-commit.bin',blob(epoch,'commit'))
            for line in git('ls-tree','-r',epoch,'--',*domains).decode().splitlines():
                meta,path=line.split('\t',1);mode,kind,sha=meta.split();assert mode!='120000' and kind=='blob';add('source/'+epoch+'/'+path,blob(sha,'blob'))
            print('SOURCE_EPOCH',epoch,flush=True)
    finally:process.stdin.close();assert process.wait(timeout=30)==0
    add('ACTUAL_ARCHIVE_LOCATIONS_V1.json',(json.dumps(locations,indent=2)+'\n').encode())
    add('BUILD_RESOURCE_PROVENANCE_V1.json',(json.dumps(resources,indent=2)+'\n').encode())
    add('SOURCE_CUSTODY_V1.json',(json.dumps(dict(sealer_source=head,actual_compiler_epochs=sorted(epochs),Git_source_bytes_preserved_as_actual_Git_blobs=True,original_generated_and_compiled_working_bytes_preserved=True,old_results_and_receipts_rewritten=False,provider_archive='RIA12_WINDOWS_RAW_V1',provider_archive_sha256='a8c06355f79f9f8f722d90ca6267775b321550bde4428d61168c796684037385'),indent=2)+'\n').encode())
    name='FROST_HYSTERESIS_STATE01_WINDOWS_RAW_V1';buffer=io.BytesIO()
    with zipfile.ZipFile(buffer,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        z.writestr('LOGICAL_FILE_INVENTORY_V1.json',json.dumps(logical,indent=2)+'\n')
        for sha,raw in sorted(objects.items()):z.writestr('objects/'+sha,raw)
    raw=buffer.getvalue();members={}
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        for member in z.namelist():value=z.read(member);members[member]=dict(bytes=len(value),sha256=SHA(value))
        for path,item in logical.items():value=z.read('objects/'+item['sha256']);assert len(value)==item['bytes'] and SHA(value)==item['sha256']
    parts=[]
    for i,at in enumerate(range(0,len(raw),50*1024*1024),1):
        value=raw[at:at+50*1024*1024];filename=name+('.zip' if len(raw)<=50*1024*1024 else f'.zip.part{i:03d}');target=P/filename;assert not target.exists();target.write_bytes(value);parts.append(dict(file=filename,bytes=len(value),sha256=SHA(value)))
    assert SHA(b''.join((P/x['file']).read_bytes() for x in parts))==SHA(raw)
    q=dict(status='ORIGINAL_WINDOWS48_BATCH_DEPENDENCIES_SOURCE_NATIVE_CONTROLS_AND_FAILED_OBSERVERS_SEALED_NOT_ADMITTED',archive=name+'.zip',bytes=len(raw),sha256=SHA(raw),parts=parts,members=members,logical_files=len(logical),unique_payloads=len(objects),all_logical_and_physical_member_bytes_readback=True,source_epochs=sorted(epochs),windows_full35_contexts=32,main_exact_cold_windows=96,old_hys2_same_root_default_pairs=4,old_hys2_model_periods_replayed=0,initial12_whole_compiled_pairs=16,current_explicit_preservation_prefixes=4,canonical_admission=False)
    (P/(name+'.json')).write_text(json.dumps(q,indent=2)+'\n');print(q['status'],len(raw),SHA(raw),len(logical),len(objects),flush=True)


if __name__=='__main__':main()
