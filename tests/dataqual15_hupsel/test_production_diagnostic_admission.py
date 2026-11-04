"""Real Git refusal controls for the single current-source/bridge boundary."""
import hashlib, importlib.util, json, subprocess, tempfile, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('successor',Path(__file__).with_name('production_diagnostic_admission.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


class Boundary(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)/'repo';self.root.mkdir()
        self.original=m.ROOT;m.ROOT=self.root
        self.git('init','-q');self.git('config','user.name','Fixture');self.git('config','user.email','fixture@example.invalid')
        files={m.APP:'old envelope\n',m.ENTRY:'old entry\n',m.STATUS:json.dumps({'native_disk_restart_20261102':{'admission':'old'}})+'\n',
               'src/physics.f90':'old physics\n','reference/input':'original\n','tools/solute/input.py':'old recipe\n'}
        files.update({p:'bound gate\n' for p in m.GATES if p!=m.ENTRY})
        for p,text in files.items():
            q=self.root/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_text(text)
        self.commit();self.base=self.git('rev-parse','HEAD')
        status=json.dumps({'native_disk_restart_20261102':{'admission':'old'},'project_diagnostic_restart_successor_20261104':{'scope':m.SCOPE}})+'\n'
        for p,text in {m.APP:'qualified envelope\n',m.ENTRY:'new entry\n',m.STATUS:status}.items():(self.root/p).write_text(text)
        self.commit()
        restore={p:dict(before=m.blob(self.base,p),after=m.blob('HEAD',p))for p in (m.APP,m.ENTRY,m.STATUS)}
        self.record=dict(predecessor=self.base,production_delta={m.APP:restore[m.APP]},bridge_restore=restore,
            predecessor_production_trees={p:m.blob(self.base,p)for p in m.AREAS},unchanged_trees={'tools/solute':m.blob(self.base,'tools/solute')},
            compiled_app_postimage_sha256=hashlib.sha256((self.root/m.APP).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
            gate_source_sha256={p:hashlib.sha256((self.root/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()for p in m.GATES})
    def tearDown(self):m.ROOT=self.original;self.temp.cleanup()
    def git(self,*a):return m.git(*a)
    def commit(self):self.git('add','.');self.git('commit','-qm','fixture')
    def test_registered_boundary(self):m.current_guard(self.record)
    def test_unregistered_physics_commit(self):
        (self.root/'src/physics.f90').write_text('new physics\n');self.commit()
        with self.assertRaisesRegex(AssertionError,'unreviewed'):m.current_guard(self.record)
    def test_different_codec_postimage(self):
        (self.root/m.APP).write_text('other envelope\n');self.commit()
        with self.assertRaises(AssertionError):m.current_guard(self.record)
    def test_dirty_physics(self):
        (self.root/'src/physics.f90').write_text('dirty\n')
        with self.assertRaisesRegex(AssertionError,'uncommitted'):m.current_guard(self.record)
    def test_untracked_physics(self):
        (self.root/'src/unknown.f90').write_text('unknown\n')
        with self.assertRaisesRegex(AssertionError,'untracked'):m.current_guard(self.record)
    def test_gate_drift(self):
        (self.root/m.GATES[-1]).write_text('unregistered gate\n')
        with self.assertRaises(AssertionError):m.current_guard(self.record)
    def test_status_drift(self):
        p=self.root/m.STATUS;p.write_text(p.read_text().replace('"old"','"unregistered"'));self.commit()
        with self.assertRaises(AssertionError):m.current_guard(self.record)
    def test_unrelated_status_does_not_rewrite_native_authority(self):
        p=self.root/m.STATUS;r=json.loads(p.read_text());r['other_chat']={'progress':'independent'};p.write_text(json.dumps(r)+'\n');self.commit()
        m.current_guard(self.record)
    def test_route_redirection_rejected(self):
        p=self.root/m.STATUS;r=json.loads(p.read_text());r['project_diagnostic_restart_successor_20261104']={'scope':'unknown'};p.write_text(json.dumps(r)+'\n');self.commit()
        with self.assertRaises(AssertionError):m.current_guard(self.record)
    def test_no_extra_production_allowlist(self):
        self.record['production_delta']['src/physics.f90']={}
        with self.assertRaises(AssertionError):m.current_guard(self.record)
    def test_predecessor_projection_is_exact(self):
        out=Path(self.temp.name)/'out';out.mkdir();view,result=m.prepare(self.record,out)
        try:
            self.assertEqual({p:m.git('rev-parse','HEAD:'+p,cwd=view)for p in m.AREAS},self.record['predecessor_production_trees'])
            self.assertEqual((view/m.ENTRY).read_text(),'old entry\n')
            self.assertEqual(json.loads((view/m.STATUS).read_text()),{'native_disk_restart_20261102':{'admission':'old'}})
            self.assertEqual((self.root/m.APP).read_text(),'qualified envelope\n')
        finally:subprocess.run(['git','worktree','remove',str(view)],cwd=self.root,check=True,capture_output=True)


if __name__=='__main__':unittest.main(verbosity=2)
