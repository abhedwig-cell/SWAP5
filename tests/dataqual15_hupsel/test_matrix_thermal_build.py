"""The build qualification cannot silently become production or broad science."""
import copy,json,unittest
from unittest.mock import patch
import matrix_thermal_build as owner

class BuildScope(unittest.TestCase):
 def test_actual_scope(self):self.assertTrue(owner.guard())
 def test_scope_refusals(self):
  mutations={
   'baseline':lambda r:r.update(baseline='0'*40),
   'production':lambda r:r.update(production_admission=True),
   'science':lambda r:r.update(whole_scientific_admission=True),
   'scope':lambda r:r.update(scope='ALL_SCIENCE'),
   'delta':lambda r:r.update(production_delta=['src/extra.f90']),
   'runner':lambda r:r.update(runner_postimage_sha256='0'*64),
   'module':lambda r:r.update(private_module_sha256='0'*64),
  }
  original=json.loads
  for name,mutate in mutations.items():
   def changed(raw,*args,**kwargs):
    result=original(raw,*args,**kwargs)
    if isinstance(result,dict) and result.get('scope')=='ACTUAL_PORTABLE_COMPLETE_BUILD_INTEGRATION_WITHOUT_PRODUCTION_MODULE_DEPLOYMENT':result=copy.deepcopy(result);mutate(result)
    return result
   with self.subTest(name=name),patch.object(owner.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):owner.guard()
if __name__=='__main__':unittest.main()
