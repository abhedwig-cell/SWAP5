"""Small contracts for preserving observation quality and calendar gaps."""
from datetime import date, timedelta
import unittest

from audit_groundwater import audit_export


class ObservationContracts(unittest.TestCase):
    def test_unknown_quality_and_daily_gaps_are_not_filled(self):
        days = [date(2024, 1, 1) + timedelta(days=i) for i in range(5)]
        export = {'metadata': {'filterfiche': 'test', 'onderkant_filter_m': 3, 'lengte_filter_m': 1},
                  'url': 'test.xml', 'status': 'OK', 'measurements': [
                      {'date': '2024-01-02', 'head_mTAW': 2, 'reliability': 'onbekend'},
                      {'date': '2024-01-04', 'head_mTAW': 2.1, 'reliability': 'goed'},
                      {'date': '2024-01-04', 'head_mTAW': 2.2, 'reliability': 'onbekend'}]}
        result = audit_export(export, days)
        self.assertEqual(result['observed_days'], 2)
        self.assertEqual(result['unobserved_days'], 3)
        self.assertEqual(result['days_with_differing_values'], ['2024-01-04'])
        self.assertEqual(result['reliability_counts'], {'onbekend': 2, 'goed': 1})
        self.assertEqual(result['screen_top_m'], 2)
        self.assertFalse(result['daily_complete'])
        self.assertFalse(result['qualified_lower_boundary'])

    def test_edge_gaps_and_invalid_values_remain_visible(self):
        days = [date(2024, 1, 1) + timedelta(days=i) for i in range(5)]
        export = {'metadata': {'filterfiche': 'test'}, 'url': 'test.xml', 'status': 'OK',
                  'measurements': [{'date': '2024-01-01', 'head_mTAW': 1},
                                   {'date': '2024-01-02', 'head_mTAW': float('nan')},
                                   {'date': 'not-a-date', 'head_mTAW': 1}]}
        result = audit_export(export, days)
        self.assertEqual(result['longest_unobserved_run_days_including_edges'], 4)
        self.assertEqual(len(result['invalid_records']), 2)
        self.assertIsNone(result['screen_top_m'])


if __name__ == '__main__':
    unittest.main()
