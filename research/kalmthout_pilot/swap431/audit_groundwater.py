#!/usr/bin/env python3
"""Audit original head observations and locate nearby series; no head prescription."""
import argparse
from collections import Counter, defaultdict
import csv
from datetime import date, timedelta
import hashlib
import json
import math
from pathlib import Path

from pyproj import Transformer


def audit_export(export, calendar):
    by_day = defaultdict(list)
    invalid = []
    observations = export.get('measurements', [])
    for m in observations:
        try:
            day = date.fromisoformat(m['date'][:10])
            assert math.isfinite(m['head_mTAW'])
        except (ValueError, TypeError, AssertionError, KeyError):
            invalid.append(m)
            continue
        if calendar[0] <= day <= calendar[-1]:
            by_day[day].append(m)
    period = [m for records in by_day.values() for m in records]
    missing_run = max_run = 0
    for day in calendar:
        missing_run = 0 if day in by_day else missing_run + 1
        max_run = max(max_run, missing_run)
    conflicting = [d.isoformat() for d, ms in sorted(by_day.items())
                   if len({m['head_mTAW'] for m in ms}) > 1]
    metadata = export['metadata']
    bottom, length = metadata.get('onderkant_filter_m'), metadata.get('lengte_filter_m')
    return {'filter_url': metadata['filterfiche'], 'name': metadata.get('GW_ID'),
            'source_url': export['url'], 'source_sha256': export.get('sha256'),
            'aquifer_hcov_v2': metadata.get('Aquifer_HCOVv2'),
            'screen_bottom_m': bottom, 'screen_top_m': bottom - length if bottom is not None and length is not None else None,
            'reference_height_mTAW_not_cell_surface': metadata.get('Z_mTAW'),
            'export_status': export['status'], 'invalid_records': invalid,
            'total_records': len(observations), 'period_records': len(period),
            'observed_days': len(by_day), 'unobserved_days': len(calendar) - len(by_day),
            'longest_unobserved_run_days_including_edges': max_run,
            'first_observed_date': min(by_day).isoformat() if by_day else None,
            'last_observed_date': max(by_day).isoformat() if by_day else None,
            'days_with_multiple_values': len([ms for ms in by_day.values() if len(ms) > 1]),
            'days_with_differing_values': conflicting,
            'head_min_mTAW': min((m['head_mTAW'] for m in period), default=None),
            'head_max_mTAW': max((m['head_mTAW'] for m in period), default=None),
            'reliability_counts': dict(Counter(m.get('reliability') for m in period)),
            'filter_status_counts': dict(Counter(m.get('filter_status') for m in period)),
            'method_counts': dict(Counter(m.get('method') for m in period)),
            'monthly_observed_days': dict(sorted(Counter(d.isoformat()[:7] for d in by_day).items())),
            'daily_complete': len(by_day) == len(calendar),
            'qualified_lower_boundary': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = args.root / 'results/swap431_groundwater/groundwater_collection.json'
    data = json.loads(source.read_text())
    start, end = date(2024, 1, 1), date(2026, 10, 1)
    calendar = [start + timedelta(days=i) for i in range((end - start).days + 1)]
    assert len(calendar) == 1005
    transform = Transformer.from_crs(31370, 32631, always_xy=True)
    filters, coordinates = [], {}
    for export in data['exports']:
        if export['status'] == 'OK':
            xml = source.parent / (export['metadata']['filterfiche'].rsplit('/', 1)[-1] + '.xml')
            assert hashlib.sha256(xml.read_bytes()).hexdigest() == export['sha256'], xml
        summary = audit_export(export, calendar)
        filters.append(summary)
        p = export['metadata']
        if summary['observed_days'] and p.get('X_mL72') is not None and p.get('Y_mL72') is not None:
            coordinates[summary['filter_url']] = transform.transform(p['X_mL72'], p['Y_mL72'])
    grid = list(csv.DictReader((args.root / 'export/grid_500m.csv').open()))
    links = []
    for cell in grid:
        xy = [float(cell['easting']), float(cell['northing'])]
        ordered = sorted((f for f in filters if f['filter_url'] in coordinates),
                         key=lambda f: (math.dist(xy, coordinates[f['filter_url']]), f['filter_url']))
        for rank, f in enumerate(ordered[:3], 1):
            links.append({'cell_id': cell['cell_id'], 'rank_by_distance': rank,
                          'distance_m': math.dist(xy, coordinates[f['filter_url']]),
                          **{k: f[k] for k in ['filter_url', 'name', 'screen_top_m', 'screen_bottom_m',
                              'aquifer_hcov_v2', 'observed_days', 'first_observed_date', 'last_observed_date',
                              'longest_unobserved_run_days_including_edges', 'qualified_lower_boundary']}})
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / 'cell_nearby_groundwater.csv').open('w') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(links[0]))
        writer.writeheader()
        writer.writerows(links)
    report = {'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'period_start': start.isoformat(), 'period_end': end.isoformat(), 'calendar_days': len(calendar),
              'filters': filters, 'filters_with_period_observations': len(coordinates),
              'daily_complete_filters': sum(f['daily_complete'] for f in filters),
              'period_observations': sum(f['period_records'] for f in filters),
              'invalid_records': sum(len(f['invalid_records']) for f in filters),
              'grid_cells': len(grid), 'nearby_links': len(links),
              'policy': ['Nearest three with actual period observations, without an inferred representativity radius.',
                         'Date-only measurements retain source date; no invented UTC sampling instant.',
                         'Unknown reliability retained as unknown, not accepted as good or discarded as bad.',
                         'Multiple same-day values reported, not averaged or interpreted as duplicate errors.',
                         'No interpolation, extrapolation, datum conversion to depth, or boundary/validation assignment.',
                         'Screen depth is relative to its source reference; no implicit cell surface equivalence.']}
    (args.output / 'groundwater_audit.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['filters_with_period_observations', 'daily_complete_filters',
                                           'period_observations', 'invalid_records', 'grid_cells', 'nearby_links']}))


if __name__ == '__main__':
    main()
