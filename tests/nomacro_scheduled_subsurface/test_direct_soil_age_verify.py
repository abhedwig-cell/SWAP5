"""Actual producer-bound direct-age proof corruption controls."""
import importlib.util
import json
from pathlib import Path
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('direct_owner',Path(__file__).with_name('direct_soil_age_verify.py'))
owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)


def leaves(value,prefix=()):
    if isinstance(value,dict):
        for k,v in value.items():yield from leaves(v,(*prefix,k))
    elif isinstance(value,list):
        for k,v in enumerate(value):yield from leaves(v,(*prefix,k))
    elif value is not None:yield prefix,value


def changed(value):
    if isinstance(value,bool):return not value
    if isinstance(value,(int,float)):return value+1
    return value+'-FOREIGN'


class Proof(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.q=json.loads((ROOT/owner.PROOF/'DIRECT_SOIL_AGE_QUALIFICATION.json').read_text());cls.reports={}
        for record,r in cls.q['archives'].items():
            with zipfile.ZipFile(ROOT/owner.PROOF/r['archive']) as z:
                for name in r['members']:
                    key=record+'|'+name
                    if key in cls.q['report_paths']:cls.reports[key]=json.loads(z.read(name))

    def test_actual_positive(self):
        owner.validate(self.q);owner.bound_claims(self.q,self.reports)

    def test_actual_report_corruptions(self):
        refused=0
        for key,report in self.reports.items():
            target=self.q
            for part in self.q['report_paths'][key]:target=target[part]
            for path,value in list(leaves(report))[:10]:
                parent=target
                for part in path[:-1]:parent=parent[part]
                original=parent[path[-1]];parent[path[-1]]=changed(value)
                try:
                    with self.assertRaises(ValueError,msg=key+' '+str(path)):owner.bound_claims(self.q,self.reports)
                    refused+=1
                finally:parent[path[-1]]=original
        self.assertGreater(refused,2800);print('ACTUAL_DIRECT_AGE_PRODUCER_CORRUPTIONS_REFUSED',refused,flush=True)

    def test_scope_source_and_guards(self):
        refused=0
        for group in ('scope','source_sha256','controller_sha256','frozen_predecessor_controllers'):
            target=self.q[group]
            for key,value in list(target.items()):
                target[key]=changed(value) if not isinstance(value,list) else value+[999]
                try:
                    with self.assertRaises(ValueError,msg=group+' '+key):owner.validate(self.q)
                    refused+=1
                finally:target[key]=value
        for key in ('water_guard_cm','chemical_mass_guard_mg_cm2','age_units','age_tolerance','runtime','functional_completion','whole_scientific_equivalence','release_readiness'):
            value=self.q[key];self.q[key]=changed(value)
            try:
                with self.assertRaises(ValueError,msg=key):owner.validate(self.q)
                refused+=1
            finally:self.q[key]=value
        print('DIRECT_AGE_SOURCE_SCOPE_GUARD_CORRUPTIONS_REFUSED',refused,flush=True)


if __name__=='__main__':unittest.main()
