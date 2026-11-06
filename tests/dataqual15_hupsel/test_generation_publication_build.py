"""Exercise the actual production builder dependency decision on real providers."""
import ast,unittest
import generation_publication_admission as owner

class PublicationBuild(unittest.TestCase):
 def test_real_native_binding_requires_support_object(self):
  for name in ('build_column.py','build_crop_column.py'):
   path=owner.ROOT/'tools/solute'/name;tree=ast.parse(path.read_text())
   assignments=[n for n in ast.walk(tree) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='needs_publication' for t in n.targets)]
   self.assertEqual(len(assignments),1)
   for source,expected in [('src/adapter/mod_crop_n_output_generation.f90',True),('src/adapter/mod_crop_n_saved_generation.f90',True),('src/adapter/mod_crop_ext_csv_file.f90',True),('app/solute_project/hupsel_rotation_restart.f90',True),('src/kernel/mod_kernel_transactions.f90',False)]:
    namespace={'ordered':[owner.ROOT/source]};exec(compile(ast.fix_missing_locations(ast.Module(body=assignments,type_ignores=[])),str(path),'exec'),namespace)
    with self.subTest(builder=name,provider=source):self.assertIs(namespace['needs_publication'],expected)
if __name__=='__main__':unittest.main()
