"""Refuse corrupt real sealed weather ledgers, worker witnesses and native state."""
import copy
import io
import json
import struct
import unittest
import zipfile

import weather_surface_verify as owner


class ActualWeatherEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.q=json.loads((owner.ROOT/owner.PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_bytes())
        cls.z=zipfile.ZipFile(owner.ROOT/owner.PROOF/'WEATHER_TERMINAL_WINDOWS_O0_RAW_ARCHIVE.zip')
        cls.build=json.loads(cls.z.read('hourly-build/BUILD.json'))
        cls.rows=owner.f.rows(cls.z,'hourly/trajectory/')
        cls.raw=cls.z.read('hourly/trajectory/accepted-column-1-day-531.zip')
        cls.meta,cls.files=owner.package(cls.raw)

    @classmethod
    def tearDownClass(cls):cls.z.close()

    def test_original_primary_and_current_source(self):
        owner.source(self.q)
        owner.f.ledger(self.rows)
        owner.f.checkpoint(self.raw,self.build,self.rows[530],True)

    def test_scope_and_denominator_inflation(self):
        for key in ('daily_water_guard_cm','daily_cde_guard_mg_cm2','integrated_cde_guard_mg_cm2','actual_full_periods','actual_days_per_full_period','actual_primary_complete_native_cold_windows','actual_public_native_refusals','actual_compiled_native_refusals','fresh_unaffected_full_periods','functional_completion','whole_scientific_equivalence','RC3_changed','runtime','predecessor'):
            q=copy.deepcopy(self.q);v=q[key];q[key]=not v if type(v) is bool else v+1 if type(v) in (int,float) else v+'-FOREIGN'
            with self.subTest(key=key),self.assertRaises(ValueError):owner.validate(q)
        q=copy.deepcopy(self.q);q['locations'].pop(next(iter(q['locations'])))
        with self.assertRaises(ValueError):owner.validate(q)

    def test_real_hourly_tail_corruptions(self):
        wire=self.files['macro.bin'];row=self.rows[530];n=self.build['project']['nodes'];epoch=self.build['project']['start_date']
        candidates=[wire[:-1],wire+b'x',b'S5HUP012'+wire[8:]]
        for at,value,fmt in [(len(wire)-4,0,'i'),(len(wire)-44,0.,'d'),(len(wire)-36,float('nan'),'d'),(len(wire)-28,-1.,'d'),(len(wire)-20,2.,'d')]:
            b=bytearray(wire);struct.pack_into('<'+fmt,b,at,value);candidates.append(bytes(b))
        for i in range(8):
            b=bytearray(wire)
            for at in (len(wire)-108,len(wire)-76):struct.pack_into('<i',b,at+4*i,struct.unpack_from('<i',wire,at+4*i)[0]+1)
            candidates.append(bytes(b))
        for wire in candidates:
            with self.assertRaises(ValueError):owner.f.root_native(wire,row,n,epoch)

    def test_real_water_cde_and_continuity_corruptions(self):
        for field in ('independent_residual_cm','kernel_residual_cm','integrated_guard_residual_cm','solute_independent_residual_mg_cm2'):
            rows=copy.deepcopy(self.rows[:2]);rows[-1][field]=1.
            with self.subTest(field=field),self.assertRaises(ValueError):owner.f.ledger(rows)
        for field in ('stock_start_cm','stock_end_cm','external_flux_cm'):
            rows=copy.deepcopy(self.rows[:2]);rows[-1][field][0]+=1.
            with self.subTest(field=field),self.assertRaises(ValueError):owner.f.ledger(rows)
        rows=copy.deepcopy(self.rows[:2]);rows[1]['day']+=1
        with self.assertRaises(ValueError):owner.f.ledger(rows)

    def test_real_original_witness_corruption(self):
        stdout=self.z.read('hourly/trajectory/original/donor.stdout')
        owner.f.root_observations(stdout,self.rows,self.build['project']['start_date'])
        bad=stdout.replace(b'HYBRID_WEATHER_ROOT_MEMORY ',b'OMITTED_WEATHER_ROOT_MEMORY ',1)
        # Removing the initial witness is harmless; remove a day witness too.
        bad=bad.replace(b'HYBRID_WEATHER_ROOT_MEMORY ',b'OMITTED_WEATHER_ROOT_MEMORY ',1)
        with self.assertRaises(ValueError):owner.f.root_observations(bad,self.rows,self.build['project']['start_date'])

    def test_actual_native_rehashed_corrupt_prefix_and_original_records(self):
        for name,offset,value,fmt in [('macro.bin',8,self.build['project']['nodes']+1,'i'),('macro.bin',48+8*(self.build['project']['nodes']+1),float('nan'),'d'),('result.end',0,2147483647,'i')]:
            files=dict(self.files);b=bytearray(files[name]);struct.pack_into('<'+fmt,b,offset,value);files[name]=bytes(b)
            meta=copy.deepcopy(self.meta);meta['files']={k:owner.digest(v) for k,v in files.items()}
            out=io.BytesIO()
            with zipfile.ZipFile(out,'w') as z:
                for k,v in files.items():z.writestr(k,v)
                z.writestr('checkpoint.json',json.dumps(meta))
            with self.assertRaises(ValueError):owner.f.checkpoint(out.getvalue(),self.build,self.rows[530],True)


if __name__=='__main__':unittest.main()
