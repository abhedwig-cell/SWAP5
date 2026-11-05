"""Reversible real source seams and explicit accepted-state selection policy."""
import copy,json,tempfile,unittest
from pathlib import Path
import composed_oxygen as run

class Policy(unittest.TestCase):
    def test_program_body_reversible(self):
        source=(run.ROOT/run.root.MAIN).read_text(encoding='utf-8');self.assertEqual(run.root.instrument(source).replace(run.root.BLOCK,''),source)
    def test_ambiguous_program_anchor_refused(self):
        with self.assertRaises(AssertionError):run.root.instrument('associate(unrelated)\n')
    def test_backend_seams_without_table_api(self):
        reg=dict(selected_profiles=[dict(receipt=[583.,584.,0.,0.,0.,0.,0.,1.,1.])]);d=run.replacements(reg)
        self.assertEqual(set(d),{run.root.MAIN,run.seams.BACKEND});self.assertNotIn('call observe_micro_table',d[run.seams.BACKEND]);self.assertNotIn('use mod_root_micro_matric_flux_table,only:observe_micro_table',d[run.seams.BACKEND])
    def test_missing_backend_anchor_refused(self):
        with self.assertRaises(AssertionError):run.seams.backend('invalid backend',dict(selected_profiles=[dict(receipt=[583.,584.])]))
    def test_selection_deduplicates_actual_receipts(self):
        trace=[[524.,525.,1.,0.,.1,0.,.9,.8,1.],[583.,584.,1.,0.,.2,0.,.8,.7,1.]];selected=run.seams.selected(trace)
        self.assertEqual([x['receipt']for x in selected['selected_profiles']],trace)
    def test_scope_is_registered_nonpromotion(self):
        r=json.loads((run.BASE/run.REG).read_text());self.assertIn('own537',r['execution'])
        for k in ('production_admission','whole_scientific_admission','migration_complete'):self.assertIs(r[k],False)
    def test_literal_metadata_exact_json_representation(self):
        from matched_micro_replay import source
        _,m=source();loaded=json.loads(json.dumps(m));self.assertEqual(loaded['reference_sha256'],m['reference_sha256']);self.assertEqual(loaded['attribution_reference_sha256'],m['attribution_reference_sha256']);self.assertEqual([tuple(p)for p in loaded['explicit_patches']],m['explicit_patches'])
    def test_actual_oracle_payload_is_retained(self):
        from composed_oxygen_evidence import collect
        with tempfile.TemporaryDirectory(prefix='composed-payload-contract-')as temp:
            p=Path(temp);(p/'0.input').write_bytes(b'original process payload\n');(p/'unused.mod').write_bytes(b'compiler module')
            self.assertEqual(collect(p),{'0.input':b'original process payload\n'})

if __name__=='__main__':unittest.main()
