"""Real repository-bound successor source guard refusal cases."""
import copy,json,unittest
import production_crop_logical_admission as gate

class Guard(unittest.TestCase):
    def test_current_source_contract(self):gate.guard(json.loads((gate.ROOT/gate.SCOPE).read_text()))
    def test_scope_and_source_refusals(self):
        original=json.loads((gate.ROOT/gate.SCOPE).read_text())
        for label in ('extra_source','wrong_before','wrong_after','missing_gate','wrong_gate','wrong_postimage','scientific_promotion'):
            r=copy.deepcopy(original)
            if label=='extra_source':r['production_delta']['src/unreviewed.f90']={}
            elif label=='wrong_before':r['bridge_restore'][gate.SOURCE]['before']='0'*40
            elif label=='wrong_after':r['bridge_restore'][gate.SOURCE]['after']='0'*40
            elif label=='missing_gate':r['gate_source_sha256'].pop(gate.ENTRY)
            elif label=='wrong_gate':r['gate_source_sha256'][gate.ENTRY]='0'*64
            elif label=='wrong_postimage':r['postimage_sha256']='0'*64
            else:r['whole_scientific_admission']=True
            with self.subTest(label=label),self.assertRaises(AssertionError):gate.guard(r)

if __name__=='__main__':unittest.main()
