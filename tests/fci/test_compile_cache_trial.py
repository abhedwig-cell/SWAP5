#!/usr/bin/env python3
"""Actual-compiler invalidation controls for the opt-in trial."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'tools/fci/compile_cache_trial.py'
FLAGS = ['-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp', '-fcheck=all',
         '-fbacktrace', '-ffpe-trap=invalid,zero,overflow', '-O0']

class Invalidation(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='swap5-cache-negative-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.out = self.root / 'out'; self.out.mkdir()
        self.source = self.root / 'demo.f90'
        self.source.write_text('module demo\ninteger,parameter::value=1\nend module\n')
        self.events = self.root / 'events.jsonl'
        self.env = {**os.environ, 'SWAP5_CACHE_DIR': str(self.root / 'cache'),
                    'SWAP5_CACHE_EVENTS': str(self.events)}
        self.env.pop('SWAP5_CACHE_DISABLED', None)

    def invoke(self, source=None, flags=None, success=True):
        cmd = ['python', str(TOOL), *(flags or FLAGS), '-J', str(self.out), '-I', str(self.out),
               '-c', str(source or self.source), '-o', str(self.out / ((source or self.source).stem + '.o'))]
        r = subprocess.run(cmd, cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(r.returncode == 0, success, r.stderr)
        return json.loads(self.events.read_text().splitlines()[-1])

    def reset(self):
        shutil.rmtree(self.out); self.out.mkdir()

    def warm(self):
        a=self.invoke(); self.assertEqual(a['event'],'MISS'); self.reset()
        b=self.invoke(); self.assertEqual(b['event'],'HIT'); self.assertEqual(a['object_sha256'],b['object_sha256'])
        return b

    def test_equal_build_and_source_change(self):
        a=self.warm(); self.reset(); self.source.write_text(self.source.read_text().replace('value=1','value=2'))
        b=self.invoke(); self.assertEqual(b['event'],'MISS'); self.assertNotEqual(a['key'],b['key'])

    def test_dependency_body_and_module_change(self):
        dep=self.root/'dep.f90';dep.write_text('module dep\ninteger,parameter::n=1\nend module\n')
        self.source.write_text('module demo\nuse dep\ninteger,parameter::value=n\nend module\n')
        self.invoke(dep);a=self.invoke();self.reset();self.invoke(dep);self.assertEqual(self.invoke()['event'],'HIT')
        self.reset();dep.write_text(dep.read_text().replace('n=1','n=2'));self.invoke(dep);b=self.invoke()
        self.assertEqual(b['event'],'MISS');self.assertNotEqual(a['key'],b['key'])
        # Change executable dependency code while keeping its module interface identical.
        self.reset();dep.write_text('module dep\ninteger,parameter::n=2\ncontains\ninteger function fun() result(r)\nr=2\nend function\nend module\n')
        self.invoke(dep);a=self.invoke();mod=hashlib.sha256((self.out/'dep.mod').read_bytes()).hexdigest()
        self.reset();dep.write_text(dep.read_text().replace('r=2','r=3'));self.invoke(dep)
        self.assertEqual(mod,hashlib.sha256((self.out/'dep.mod').read_bytes()).hexdigest())
        b=self.invoke();self.assertEqual(b['event'],'MISS');self.assertNotEqual(a['key'],b['key'])

    def test_implicit_current_directory_module(self):
        dep=self.root/'dep.f90';dep.write_text('module dep\ninteger,parameter::n=1\nend module\n')
        self.source.write_text('module demo\nuse dep\ninteger,parameter::value=n\nend module\n')
        def build_dep():
            subprocess.run([self.env['SWAP5_REAL_FC'],*FLAGS,'-J',str(self.root),'-I',str(self.root),
                            '-c',str(dep),'-o',str(self.root/'dep.o')],cwd=self.root,check=True)
        build_dep();a=self.warm();self.reset();dep.write_text(dep.read_text().replace('n=1','n=2'));build_dep()
        b=self.invoke();self.assertEqual(b['event'],'MISS');self.assertNotEqual(a['key'],b['key'])

    def test_flags_and_environment(self):
        a=self.warm();self.reset();b=self.invoke(flags=[f.replace('-O0','-O2') for f in FLAGS]);self.assertEqual(b['event'],'MISS')
        self.reset();self.env['SWAP5_CACHE_TEST_ENV']='different';c=self.invoke();self.assertEqual(c['event'],'MISS');self.assertNotEqual(a['key'],c['key'])

    def test_changed_compiler_wrapper(self):
        self.warm();self.reset();fc=self.root/'gfortran';fc.write_text(Path(self.env['SWAP5_REAL_FC']).read_text()+'\n# changed wrapper\n');fc.chmod(0o755)
        p=self.root/'profile.json';j=json.loads(Path(self.env['SWAP5_CACHE_PROFILE']).read_text());j['roots'].append(str(fc));p.write_text(json.dumps(j))
        self.env.update(SWAP5_REAL_FC=str(fc),SWAP5_CACHE_PROFILE=str(p));self.assertEqual(self.invoke()['event'],'MISS')
        self.reset();fc.write_text(fc.read_text()+'# another changed byte\n');self.assertEqual(self.invoke()['event'],'MISS')

    def test_corruption_rebuilds(self):
        a=self.warm();self.reset();entry=Path(self.env['SWAP5_CACHE_DIR'])/a['key'];(Path(self.env['SWAP5_CACHE_DIR'])/'_blobs'/a['object_sha256']).write_bytes(b'corrupt')
        b=self.invoke();self.assertEqual(b['event'],'MISS');self.assertEqual(a['object_sha256'],b['object_sha256'])
        self.assertIn('INVALID',[json.loads(x)['event'] for x in self.events.read_text().splitlines()])
        self.reset();(entry/'manifest.json').write_text('{invalid');self.assertEqual(self.invoke()['event'],'MISS')

    def test_include_and_unknown_flags_bypass(self):
        inc=self.root/'included.f90';inc.write_text('integer,parameter::value=1\n')
        self.source.write_text("module demo\ninclude '"+str(inc)+"'\nend module\n")
        self.assertEqual(self.invoke()['event'],'BYPASS')
        self.source.write_text('module demo\nend module\n');self.reset()
        self.assertEqual(self.invoke(flags=FLAGS+['-g'])['event'],'BYPASS')

    def test_large_hash_mapping_and_preserved_timestamp(self):
        import runpy
        api=runpy.run_path(str(TOOL))
        data=self.root/'large';data.write_bytes(b'A'*(2*1024*1024))
        before=data.stat();a=api['file_hash'](data)
        self.assertEqual(a,hashlib.sha256(data.read_bytes()).hexdigest())
        data.write_bytes(b'B'*before.st_size);os.utime(data,ns=(before.st_atime_ns,before.st_mtime_ns))
        b=api['file_hash'](data);self.assertNotEqual(a,b)
        self.assertEqual(b,hashlib.sha256(data.read_bytes()).hexdigest())
        self.warm();self.reset();stamp=self.source.stat()
        self.source.write_text(self.source.read_text().replace('value=1','value=2'))
        os.utime(self.source,ns=(stamp.st_atime_ns,stamp.st_mtime_ns));self.assertEqual(self.invoke()['event'],'MISS')

    def test_shared_module_and_no_duplicate_restore(self):
        dep=self.root/'dep.f90';dep.write_text('module dep\ninteger,parameter::n=1\nend module\n')
        self.source.write_text('module demo\nuse dep\ninteger,parameter::value=n\nend module\n')
        self.invoke(dep);self.invoke();self.reset();self.invoke(dep);r=self.invoke()
        self.assertEqual(r['event'],'HIT');self.assertEqual(r['module_skips'],1);self.assertEqual(r['module_copies'],1)
        module=hashlib.sha256((self.out/'demo.mod').read_bytes()).hexdigest()
        (Path(self.env['SWAP5_CACHE_DIR'])/'_blobs'/module).write_bytes(b'corrupt module')
        self.reset();self.invoke(dep);self.assertEqual(self.invoke()['event'],'MISS')
        self.assertEqual(hashlib.sha256((self.out/'demo.mod').read_bytes()).hexdigest(),module)

    def test_validation_survives_python_optimization(self):
        self.env['PYTHONOPTIMIZE']='1'
        r=self.warm();self.reset();blob=Path(self.env['SWAP5_CACHE_DIR'])/'_blobs'/r['object_sha256']
        blob.write_bytes(b'corrupt')
        self.assertEqual(self.invoke()['event'],'MISS')

    def test_failure_not_published_and_unknown_profile(self):
        self.source.write_text('invalid fortran\n');self.assertEqual(self.invoke(success=False)['event'],'FAILED')
        self.assertFalse(any(p.is_dir() and p.name!='_blobs' for p in Path(self.env['SWAP5_CACHE_DIR']).iterdir()))
        self.source.write_text('module demo\nend module\n');p=self.root/'unknown.json';p.write_text('{}');self.env['SWAP5_CACHE_PROFILE']=str(p)
        self.assertEqual(self.invoke()['event'],'BYPASS')

if __name__=='__main__':unittest.main(verbosity=2)
