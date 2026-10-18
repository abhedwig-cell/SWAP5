#!/usr/bin/env python3
"""Create source-driven cell candidates; all remain unparameterized."""
import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inventory', type=Path)
    args = parser.parse_args()
    root = args.inventory
    coverage = {r['cell_id']: r for r in csv.DictReader((root / 'cell_source_coverage.csv').open())}
    scores = defaultdict(lambda: defaultdict(float))
    representative = defaultdict(lambda: defaultdict(float))
    unknown_habitat_rows = 0
    with (root / 'cell_source_fractions.csv').open() as handle:
        for row in csv.DictReader(handle):
            cell, layer = row['cell_id'], row['layer']
            codes, fraction = json.loads(row['source_codes_json']), float(row['cell_fraction'])
            if cell == 'KAL_0496':
                representative[layer][codes[0]] += fraction
            if layer == 'bwk':
                for code, label in [('4030', 'dry_heath_4030'), ('4010', 'wet_heath_4010')]:
                    for i in range(1, len(codes), 2):
                        if codes[i].strip() == code:
                            if not codes[i + 1].strip():
                                unknown_habitat_rows += 1
                                continue
                            percent = float(codes[i + 1])
                            assert 0 <= percent <= 100
                            scores[label][cell] += fraction * percent / 100
            elif layer == 'landuse2025':
                for code, label in [('12', 'forest'), ('13', 'arable'), ('14', 'agricultural_grass'),
                                    ('1', 'houses_gardens'), ('17', 'open_water')]:
                    if codes[0] == code:
                        scores[label][cell] += fraction
    selected, used = [], set()
    for group, values in scores.items():
        count = 0
        for cell, score in sorted(values.items(), key=lambda r: (-r[1], r[0])):
            if cell in used or score < 0.1:
                continue
            if float(coverage[cell]['landuse2025_coverage_fraction']) < 0.95:
                continue
            selected.append({'group': group, 'cell_id': cell, 'mapped_group_fraction': score,
                             'soil_coverage_fraction': float(coverage[cell]['soil_coverage_fraction']),
                             'route': 'surface_water_separate_contract' if group == 'open_water' else 'parameterization_required',
                             'ready_for_simulation': False})
            used.add(cell)
            count += 1
            if count == 2:
                break
    report = {'candidate_cells': selected, 'representative_cell_fractions': representative,
              'matching_habitat_rows_with_unknown_percentage': unknown_habitat_rows,
              'selection': 'Two highest mapped fractions per group, distinct cells, >=95% land-use coverage.',
              'limitations': ['Habitat codes must match exactly; composite codes are not split by assumption.',
                             'This is a source-driven shortlist, not a representative sampling proof or validated model input.',
                             'Houses and gardens is not an impervious fraction.',
                             'Open water requires a separate process contract, not a bare-soil SWAP column.']}
    (root / 'candidate_cells.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
