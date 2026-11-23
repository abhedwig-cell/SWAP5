"""Regression of the actual clean-Windows patch refusal and opaque raw custody."""
import hashlib,subprocess,unittest
from pathlib import Path
from explicit_bottom9_snow_history_source_custody import ROOT,original_git_payload

class OriginalGitText(unittest.TestCase):
 def blob(self,raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
 def original(self,path):return subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT)
 def test_original_patch_crlf_spelling(self):
  path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_HISTORY_PROPOSED_V1.patch';original=self.original(path);self.assertNotIn(b'\r\n',original);working=original.replace(b'\n',b'\r\n');proven,storage=original_git_payload(working,path,self.blob(original));self.assertEqual(proven,original);self.assertIn('GIT_TEXT_CRLF_LF',storage);self.assertNotEqual(self.blob(working),self.blob(original))
 def test_changed_patch_content_refused(self):
  path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_HISTORY_PROPOSED_V1.patch';original=self.original(path)
  with self.assertRaises(AssertionError):original_git_payload(original.replace(b'\n',b'\r\n')+b'Changed evidence\r\n',path,self.blob(original))
 def test_opaque_archive_exact_and_corruption_refused(self):
  path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_HISTORY_INPUTS_V1.zip';original=self.original(path);proven,storage=original_git_payload(original,path,self.blob(original));self.assertEqual(proven,original);self.assertEqual(storage,'ACTUAL_WORKING_BYTES_EXACT');self.assertIn(b'\0',original)
  with self.assertRaises(AssertionError):original_git_payload(original+b'\r\n',path,self.blob(original))

if __name__=='__main__':unittest.main()
