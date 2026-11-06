import copy,json,unittest
from unittest.mock import patch
import generation_publication_admission as p

class PublicationAdmission(unittest.TestCase):
 def test_exact_current_postimages(self):self.assertTrue(p.guard())
 def test_corrupt_scope_refusals(self):
  source=sorted(p.SOURCES)[0]
  cases={
   'predecessor':lambda r:r.update(predecessor='0'*40),
   'scope':lambda r:r.update(scope='ALL_PLATFORMS_ALL_SCIENCE'),
   'phase':lambda r:r.update(phase='SOURCE_ONLY'),
   'science':lambda r:r.update(whole_scientific_admission=True),
   'windows':lambda r:r.update(windows_path_scope='ARBITRARY_UNICODE'),
   'failure':lambda r:r.update(generation_reported_failure_contract='AFTER_REPLACEMENT_ALLOWED'),
   'restart':lambda r:r.update(restart_directory_sync_stage6='IGNORED'),
   'canonical':lambda r:r['private_canonical'].update(tree='0'*40),
   'checks':lambda r:r['private_canonical'].update(final_workflows=0),
   'delta':lambda r:r['production_delta'].update({'src/extra.f90':{}}),
   'bridge':lambda r:r['bridge_restore'].update({'app/extra.f90':{}}),
   'origin':lambda r:r['bridge_restore'][source].update(before='0'*40),
   'postimage':lambda r:r['qualified_full_postimage_sha256'].update({source:'0'*64}),
   'old_tree':lambda r:r['predecessor_production_trees'].update(app='0'*40),
   'gate':lambda r:r['gate_source_sha256'].pop(p.ENTRY),
   'artifact':lambda r:r['qualified_artifact_records'].pop(next(iter(r['qualified_artifact_records']))),
  }
  original=json.loads
  for name,mutate in cases.items():
   def changed(raw,*a,**k):
    r=original(raw,*a,**k)
    if isinstance(r,dict) and r.get('scope')=='POSIX_AND_ASCII_WINDOWS_PRECOMMIT_COMPLETE_GENERATION_PUBLICATION':r=copy.deepcopy(r);mutate(r)
    return r
   with self.subTest(name=name),patch.object(p.json,'loads',side_effect=changed):
    with self.assertRaises(AssertionError):p.guard()
if __name__=='__main__':unittest.main()
