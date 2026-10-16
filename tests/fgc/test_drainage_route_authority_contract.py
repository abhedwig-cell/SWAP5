"""Synthetic documentation-contract checks, never a production drainage model."""
from copy import deepcopy
from decimal import Decimal
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def check_declarations(routes, receipts):
    """Proposed receipt semantics only; physical identity is supplied, not inferred."""
    by_id = {}
    physical = set()
    for route in routes:
        if not route['physical_path'] or not route['provenance']:
            raise ValueError('unresolved physical identity')
        if route['id'] in by_id or route['physical_path'] in physical:
            raise ValueError('same path independently declared twice')
        if route['evaluator'] not in {'SWAP', 'MODFLOW', 'SURFACE_WATER'}:
            raise ValueError('unresolved evaluator')
        if route['source'] == route['destination']:
            raise ValueError('same physical source/destination')
        if route['source_role'] != 'PHYSICAL_DOMAIN_DECLARED':
            raise ValueError('no physical source authority')
        if set(route['independent_evaluators']) != {route['evaluator']} or len(route['independent_evaluators']) != 1:
            raise ValueError('multiple independent calculations')
        by_id[route['id']] = route
        physical.add(route['physical_path'])
    windows = set()
    transfers = set()
    for receipt in receipts:
        route = by_id[receipt['route']]
        key = (receipt['route'], receipt['window'])
        if key in windows or receipt['transfer'] in transfers:
            raise ValueError('duplicate accepted publication')
        windows.add(key)
        transfers.add(receipt['transfer'])
        if not receipt['accepted'] or not receipt['origin']:
            raise ValueError('trial or unresolved committed origin')
        if receipt['units'] != 'm3':
            raise ValueError('unconverted amount')
        amount = Decimal(receipt['amount'])
        if not amount.is_finite():
            raise ValueError('nonfinite amount')
        expected = [(route['source'], -amount), (route['destination'], amount)]
        actual = [(leg['domain'], Decimal(leg['signed_amount'])) for leg in receipt['physical_legs']]
        if len(actual) != 2 or sorted(actual) != sorted(expected):
            raise ValueError('duplicate or mismatched physical budget leg')
        for mirror in receipt['mirrors']:
            if mirror['transfer'] != receipt['transfer'] or Decimal(mirror['amount']) != amount:
                raise ValueError('mirror is not the same accepted transfer')
            if mirror['adds_physical_leg']:
                raise ValueError('mirror double-books water')


def example():
    # Entirely invented test labels, not a real application topology.
    routes = []
    receipts = []
    for name, owner, source, amount in [('local', 'SWAP', 'column_A', '3'), ('regional', 'MODFLOW', 'aquifer_B', '2')]:
        routes.append(dict(id=name, physical_path='synthetic_'+name, provenance='synthetic_test_only',
                           evaluator=owner, independent_evaluators=[owner], source=source,
                           destination='EXTERNAL', source_role='PHYSICAL_DOMAIN_DECLARED'))
        receipts.append(dict(route=name, window='w1', transfer=name+'_w1', accepted=True,
                             origin='synthetic_committed_origin', units='m3', amount=amount,
                             physical_legs=[dict(domain=source, signed_amount='-'+amount),
                                            dict(domain='EXTERNAL', signed_amount=amount)], mirrors=[]))
    return routes, receipts


class DrainageAuthorityContract(unittest.TestCase):
    def test_distinct_swap_and_modflow_paths_allowed(self):
        check_declarations(*example())

    def test_same_flux_may_be_mirrored_without_new_physical_leg(self):
        routes, receipts = example()
        receipts[0]['mirrors'] = [dict(transfer='local_w1', amount='3', adds_physical_leg=False)]
        check_declarations(routes, receipts)

    def test_reverse_signed_exchange_and_zero(self):
        for amount in ['-3', '0']:
            routes, receipts = example()
            receipts[0]['amount'] = amount
            receipts[0]['physical_legs'][0]['signed_amount'] = str(-Decimal(amount))
            receipts[0]['physical_legs'][1]['signed_amount'] = amount
            check_declarations(routes, receipts)

    def reject(self, change):
        routes, receipts = example()
        change(routes, receipts)
        with self.assertRaises(ValueError):
            check_declarations(routes, receipts)

    def test_same_path_under_alias_rejected(self):
        self.reject(lambda r, q: r[1].update(physical_path=r[0]['physical_path']))

    def test_two_independent_models_same_route_rejected(self):
        self.reject(lambda r, q: r[0].update(independent_evaluators=['SWAP', 'MODFLOW']))

    def test_unresolved_owner_rejected(self):
        self.reject(lambda r, q: r[0].update(evaluator='UNRESOLVED'))

    def test_sto_capacitance_not_physical_source(self):
        self.reject(lambda r, q: r[1].update(source_role='HEAD_STATE_CAPACITANCE'))

    def test_duplicate_sink_rejected(self):
        self.reject(lambda r, q: q[0]['physical_legs'].append(deepcopy(q[0]['physical_legs'][0])))

    def test_mirror_extra_sink_rejected(self):
        self.reject(lambda r, q: q[0].update(mirrors=[dict(transfer='local_w1', amount='3', adds_physical_leg=True)]))

    def test_rejected_trial_not_accepted_receipt(self):
        self.reject(lambda r, q: q[0].update(accepted=False))

    def test_restart_republication_rejected(self):
        self.reject(lambda r, q: q.append(deepcopy(q[0])))

    def test_unconverted_rate_rejected(self):
        self.reject(lambda r, q: q[0].update(units='cm/day'))

    def test_current_production_stays_none(self):
        contract = json.loads((ROOT/'integration/f-gc/F-GC_FIXED_INTERFACE_COUPLING_CONTRACT.json').read_text())
        self.assertEqual(contract['drainage']['admitted_owner'], 'NONE')
        self.assertEqual(contract['storage']['modflow_sto_role'], 'HEAD_STATE_CAPACITANCE')
        source = (ROOT/'src/runtime/mod_fmr_production_application_bootstrap.f90').read_text()
        self.assertIn('if (any(authority_cells%drainage_owner /= GW_DRAINAGE_OWNER_NONE)) return', source)
        self.assertIn('if (any(authority_cells%storage_state_role /= GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE)) return', source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
