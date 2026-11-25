"""Actual canonical Git archive byte readers; no source or path projection."""
import hashlib,io,json,subprocess,zipfile
from pathlib import Path
import sys
R=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(R/'tests/nomacro_drainage'))
from explicit_bottom9_archive_science import ReadView
BASE='8dbe3db7c7832dd6a1f86c4275cd43f054552df3'
PREFIX='integration/f-ci/nomacro-complete01/'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
class CanonicalArchive:
    def __init__(self,name):
        def actual(file):return subprocess.check_output(['git','show',BASE+':'+PREFIX+file],cwd=R)
        self.record=json.loads(actual(name+'.json'));parts=[]
        for item in self.record['parts']:
            raw=actual(item['file']);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];parts.append(raw)
        raw=b''.join(parts);assert len(raw)==self.record['bytes'] and SHA(raw)==self.record['sha256']
        self.z=zipfile.ZipFile(io.BytesIO(raw));self.names=self.record['members']
        assert len(self.z.namelist())==len(set(self.z.namelist())) and set(self.z.namelist())==set(self.names)
    def get(self,name):
        raw=self.z.read(name);item=self.names[name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw
    def view(self,name):return ReadView(self,name)
class CanonicalLogicalArchive:
    def __init__(self,name):
        self.physical=CanonicalArchive(name);self.record=self.physical.record;self.names=json.loads(self.physical.get('LOGICAL_FILE_INVENTORY_V1.json'))
        assert len(self.names)==self.record['logical_files'] and all('objects/'+x['sha256'] in self.physical.names for x in self.names.values())
    def get(self,name):
        item=self.names[name];raw=self.physical.get('objects/'+item['sha256']);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw
    def view(self,name):return ReadView(self,name)
