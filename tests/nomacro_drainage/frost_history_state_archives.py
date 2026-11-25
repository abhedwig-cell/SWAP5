"""Explicit original archive/Git byte locations; no filesystem or source projection."""
import hashlib,io,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'
BASE='e0461f005b95b9f68bc70d4d4698eff903bc04ed'


class LogicalArchive:
    def __init__(self,name,stack):
        self.physical=Archive(P,name,stack);self.record=self.physical.record
        self.names=json.loads(self.physical.get('LOGICAL_FILE_INVENTORY_V1.json'))
        assert len(self.names)==self.record['logical_files']
        assert all('objects/'+item['sha256'] in self.physical.names for item in self.names.values())
    def get(self,name):
        item=self.names[name];raw=self.physical.get('objects/'+item['sha256'])
        assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
        return raw
    def view(self,name):return ReadView(self,name)


class OriginalProviderArchive:
    """Read the once-preserved original provider from its accepted Git objects."""
    def __init__(self,stack):
        prefix='integration/f-ci/nomacro-complete01/';name='RIA12_WINDOWS_RAW_V1'
        git=lambda path:subprocess.check_output(['git','show',BASE+':'+prefix+path],cwd=R)
        self.record=json.loads(git(name+'.json'));parts=[]
        assert self.record['sha256']=='a8c06355f79f9f8f722d90ca6267775b321550bde4428d61168c796684037385'
        for item in self.record['parts']:
            raw=git(item['file']);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];parts.append(raw)
        raw=b''.join(parts);assert len(raw)==self.record['bytes'] and SHA(raw)==self.record['sha256']
        self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));self.names=self.record['members']
        assert len(self.z.namelist())==len(set(self.z.namelist())) and set(self.z.namelist())==set(self.names)
    def get(self,name):
        raw=self.z.read(name);item=self.names[name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw
    def view(self,name):return ReadView(self,name)


class BuildReference:
    def __init__(self,store,prefix):self.store,self.prefix=store,prefix
    def __truediv__(self,name):
        assert name.startswith('build/') and '..' not in Path(name).parts
        return ReadView(self.store,self.prefix+'/'+name[len('build/'):])


class Locations:
    def __init__(self,store,bindings):self.store,self.bindings=store,{str(k).replace('\\','/').rstrip('/'):v['prefix'].rstrip('/') for k,v in bindings.items()}
    def resolve(self,path):
        path=str(path).replace('\\','/').rstrip('/');matches=[p for p in self.bindings if path==p or path.startswith(p+'/')];assert matches,'Unmapped original archive location '+path
        key=max(matches,key=len);tail=path[len(key):].lstrip('/');return self.store.view(self.bindings[key]+('/'+tail if tail else ''))
