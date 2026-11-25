"""Explicit immutable Git archive source; never a pretend working directory."""
import json,re,subprocess
from pathlib import Path,PurePosixPath


class GitArchiveSource:
    def __init__(self,repository,revision,prefix='integration/f-ci/nomacro-complete01'):
        self.repository=Path(repository).resolve();self.revision=revision
        assert re.fullmatch('[0-9a-f]{40}',revision)
        self.prefix=self.safe(prefix)
        assert self.git('cat-file','-t',revision).strip()==b'commit'
        assert not self.git('for-each-ref','--format=%(refname)','refs/replace')

    @staticmethod
    def safe(path):
        value=PurePosixPath(path)
        assert not value.is_absolute() and '..' not in value.parts and ':' not in str(value)
        return value.as_posix()

    def git(self,*args):return subprocess.check_output(['git',*args],cwd=self.repository)
    def __truediv__(self,name):return GitArchiveFile(self,self.prefix+'/'+self.safe(name))
    def __str__(self):return 'GitArchiveSource('+self.revision+':'+self.prefix+')'

    def archive_bytes(self,name):
        record=json.loads((self/(name+'.json')).read_text())
        return record,[(self/item['file']).read_bytes() for item in record['parts']]


class GitArchiveFile:
    def __init__(self,source,path):self.source=source;self.path=source.safe(path)
    def read_bytes(self):return self.source.git('show',self.source.revision+':'+self.path)
    def read_text(self,encoding='utf8',**kwargs):return self.read_bytes().decode(encoding,**kwargs)
    def is_file(self):
        response=subprocess.run(['git','cat-file','-t',self.source.revision+':'+self.path],cwd=self.source.repository,capture_output=True)
        return response.returncode==0 and response.stdout.strip()==b'blob'
    def __str__(self):return 'GitArchiveFile('+self.source.revision+':'+self.path+')'
