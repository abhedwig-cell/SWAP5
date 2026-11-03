"""Actual Git mutation controls for the exact I/O admission boundary."""
import hashlib,importlib.util,json,subprocess,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('gate',Path(__file__).with_name('verify_native_restart_admission.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class Boundary(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)/'repo';self.root.mkdir()
        self.original=m.ROOT;m.ROOT=self.root
        self.git('init','-q');self.git('config','user.name','Fixture');self.git('config','user.email','fixture@example.invalid')
        for name,text in {'src/model.f90':'old physics\n','app/codec.f90':'old codec\n','reference/input':'original\n','tools/recipe.py':'old recipe\n','tests/gate.py':'bound gate\n'}.items():
            p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
        self.commit();base=self.git('rev-parse','HEAD')
        (self.root/'app/codec.f90').write_text('new codec\n');(self.root/'app/native.c').write_text('native I/O\n')
        (self.root/'tools/recipe.py').write_text('new recipe\n');self.commit()
        paths=['app/codec.f90','app/native.c','tools/recipe.py']
        restore={p:dict(before=m.blob(base,p),after=m.blob('HEAD',p))for p in paths}
        self.record=dict(predecessor=base,preservation_restore=restore,
            production_delta={p:restore[p]for p in paths if p.startswith('app/')},
            predecessor_production_trees={p:m.blob(base,p)for p in m.AREAS},
            gate_source_sha256={'tests/gate.py':hashlib.sha256(b'bound gate\n').hexdigest()})
    def tearDown(self):m.ROOT=self.original;self.temp.cleanup()
    def git(self,*args):return m.git(*args)
    def commit(self):self.git('add','.');self.git('commit','-qm','fixture')
    def test_exact_boundary_passes(self):m.guard(self.record)
    def test_unreviewed_physics_commit_rejected(self):
        (self.root/'src/model.f90').write_text('changed physics\n');self.commit()
        with self.assertRaisesRegex(AssertionError,'unreviewed'):m.guard(self.record)
    def test_forged_codec_postimage_rejected(self):
        (self.root/'app/codec.f90').write_text('different codec\n');self.commit()
        with self.assertRaises(AssertionError):m.guard(self.record)
    def test_untracked_production_rejected(self):
        (self.root/'app/unreviewed.c').write_text('unknown\n')
        with self.assertRaisesRegex(AssertionError,'untracked'):m.guard(self.record)
    def test_dirty_physics_rejected(self):
        (self.root/'src/model.f90').write_text('dirty\n')
        with self.assertRaisesRegex(AssertionError,'uncommitted'):m.guard(self.record)
    def test_recipe_drift_rejected(self):
        (self.root/'tools/recipe.py').write_text('different recipe\n');self.commit()
        with self.assertRaises(AssertionError):m.guard(self.record)
    def test_validator_drift_rejected(self):
        (self.root/'tests/gate.py').write_text('unbound gate\n')
        with self.assertRaises(AssertionError):m.guard(self.record)
    def test_exact_accounting_extension_is_preserved_as_predecessor(self):
        path='src/stock.f90';(self.root/path).write_text('reviewed stock comparison\n');self.commit()
        pin=dict(before=None,after=m.blob('HEAD',path))
        self.record['production_delta'][path]=pin;self.record['preservation_restore'][path]=pin
        m.guard(self.record)
        out=Path(self.temp.name)/'stock-view';out.mkdir();view,result=m.prepare(self.record,out)
        try:
            self.assertFalse((view/path).exists())
            self.assertEqual(m.git('rev-parse','HEAD:src',cwd=view),self.record['predecessor_production_trees']['src'])
        finally:subprocess.run(['git','worktree','remove',str(view)],cwd=self.root,check=True)
    def test_accounting_extension_rejects_different_postimage(self):
        path='src/stock.f90';(self.root/path).write_text('reviewed stock comparison\n');self.commit()
        pin=dict(before=None,after=m.blob('HEAD',path))
        self.record['production_delta'][path]=pin;self.record['preservation_restore'][path]=pin
        (self.root/path).write_text('unreviewed energy law\n');self.commit()
        with self.assertRaises(AssertionError):m.guard(self.record)
    def test_committed_projection_is_exact_and_does_not_change_current(self):
        out=Path(self.temp.name)/'view';out.mkdir();view,result=m.prepare(self.record,out)
        try:
            self.assertEqual({p:m.git('rev-parse','HEAD:'+p,cwd=view)for p in m.AREAS},self.record['predecessor_production_trees'])
            self.assertEqual(m.git('status','--porcelain',cwd=view),'')
            self.assertEqual((view/'app/codec.f90').read_text(),'old codec\n')
            self.assertFalse((view/'app/native.c').exists())
            self.assertEqual((self.root/'app/codec.f90').read_text(),'new codec\n')
        finally:subprocess.run(['git','worktree','remove',str(view)],cwd=self.root,check=True)

if __name__=='__main__':unittest.main(verbosity=2)
