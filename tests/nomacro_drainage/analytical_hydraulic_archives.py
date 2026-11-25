"""Read exact original analytical ZIP byte parts without materializing copies."""
import hashlib
import io
import json
from pathlib import Path
import zipfile
from frost_cde_drainage_science import View

SHA=lambda raw:hashlib.sha256(raw).hexdigest()


class Archive:
    def __init__(self,proof,name,stack):
        from frost_boundary_git_archive import GitArchiveSource
        if isinstance(proof,GitArchiveSource):
            self.record,raw=proof.archive_bytes(name);q=self.record;parts=q['parts']
            assert parts and all(item['file']==(q['archive'] if len(parts)==1 else q['archive']+f'.part{i:03d}') for i,item in enumerate(parts,1))
            assert all(len(value)==item['bytes'] and SHA(value)==item['sha256'] for item,value in zip(parts,raw))
            value=b''.join(raw);assert len(value)==q['bytes'] and SHA(value)==q['sha256']
            self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(value)));self.names=q['members']
            assert len(self.z.namelist())==len(set(self.z.namelist()))==len(self.names) and set(self.z.namelist())==set(self.names)
            return
        proof=Path(proof);self.record=json.loads((proof/(name+'.json')).read_text(encoding='utf-8'));q=self.record
        parts=q['parts'];assert parts and all(item['file']==(q['archive'] if len(parts)==1 else q['archive']+f'.part{i:03d}') for i,item in enumerate(parts,1))
        if len(parts)==1:
            path=proof/parts[0]['file'];assert path.stat().st_size==q['bytes'] and SHA(path.read_bytes())==q['sha256']==parts[0]['sha256']
            self.z=stack.enter_context(zipfile.ZipFile(path))
        else:
            raw=[]
            for item in parts:
                value=(proof/item['file']).read_bytes();assert len(value)==item['bytes'] and SHA(value)==item['sha256'];raw.append(value)
            value=b''.join(raw);assert len(value)==q['bytes'] and SHA(value)==q['sha256'];self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(value)))
        self.names=q['members'];assert len(self.z.namelist())==len(set(self.z.namelist()))==len(self.names) and set(self.z.namelist())==set(self.names)

    def get(self,name):
        raw=self.z.read(name);item=self.names[name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw

    def view(self,name):return View(self,name)
