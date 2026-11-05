"""Contract controls for the single admitted rejection-witness substitution."""
import unittest
import rotation_native_runtime as runtime

class Projection(unittest.TestCase):
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
