"""Independent fail-closed mutation controls for default compatibility."""
import importlib.util,pathlib,subprocess,unittest
p=pathlib.Path(__file__).with_name('low_air_successor_authority.py');s=importlib.util.spec_from_file_location('authority',p);a=importlib.util.module_from_spec(s);s.loader.exec_module(a)
class Controls(unittest.TestCase):
 def test_exact_projection(self):
  for p in a.PATHS:
   old=subprocess.check_output(['git','show',a.BASE+':'+p],cwd=a.ROOT).decode()
   self.assertEqual(a.project_default_off(p,(a.ROOT/p).read_text()),old)
 def test_unrecognized_changes(self):
  for path,old,new in [(a.CONTRACT,'.false.','.true.'),(a.RUNTIME,'0.9_real64','0.95_real64'),(a.RUNTIME,'0.2025_real64','0.25_real64')]:
   text=(a.ROOT/path).read_text().replace(old,new)
   with self.assertRaises(ValueError):a.project_default_off(path,text)
 def test_baseline_mutation_cannot_project(self):
  for path in a.PATHS:
   text=(a.ROOT/path).read_text();old=subprocess.check_output(['git','show',a.BASE+':'+path],cwd=a.ROOT).decode()
   self.assertNotEqual(a.project_default_off(path,text+'\n! foreign mutation\n'),old)
if __name__=='__main__':unittest.main()
