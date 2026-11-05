"""Contract controls for the single admitted rejection-witness substitution."""
import copy,json,unittest
import rotation_native_runtime as runtime
import rotation_native_admission as admission

class Projection(unittest.TestCase):
    def test_current_crc_scope_and_real_git_bound_defects(self):
        record=json.loads((runtime.ROOT/admission.SCOPE).read_text());admission.guard(record)
        for label in ('source','before','after','missing','gate','body','promotion'):
            r=copy.deepcopy(record)
            if label=='source':r['production_delta']['src/unreviewed.f90']={}
            elif label=='before':r['bridge_restore'][admission.SOURCE]['before']='0'*40
            elif label=='after':r['bridge_restore'][admission.SOURCE]['after']='0'*40
            elif label=='missing':r['gate_source_sha256'].pop(admission.ENTRY)
            elif label=='gate':r['gate_source_sha256'][admission.ENTRY]='0'*64
            elif label=='body':r['postimage_sha256']='0'*64
            else:r['whole_scientific_admission']=True
            with self.subTest(label=label),self.assertRaises(AssertionError):admission.guard(r)
    def test_exact_authority_and_all_assertions(self):
        runtime.guard()
        before=(runtime.ROOT/runtime.ORIGINAL).read_text();donor=(runtime.ROOT/runtime.DONOR).read_text()
        after=runtime.projection(before,donor)
        self.assertEqual([s for s in before.splitlines()if 'call require('in s],[s for s in after.splitlines()if 'call require('in s])
        self.assertNotEqual(before,after)

    def test_stale_and_unsupported_witnesses_refused(self):
        original=(runtime.ROOT/runtime.ORIGINAL).read_text();donor=(runtime.ROOT/runtime.DONOR).read_text()
        for before,source in ((original.replace(runtime.OLD,''),donor),(original+'\n'+runtime.OLD,donor),(original,donor.replace('temperature_reference_c=-20d0','temperature_reference_c=-21d0')),(original,donor.replace('nfrac_biomass=1d0','nfrac_biomass=-1d0'))):
            with self.assertRaises(AssertionError):runtime.projection(before,source)

if __name__=='__main__':unittest.main()
