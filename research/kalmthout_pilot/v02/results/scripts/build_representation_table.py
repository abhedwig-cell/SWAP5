"""Reproduce the reporting-population screen, without rerunning native physics.

Uses trusted, locally preserved NPZ metadata (its string arrays require pickle).
The default year and column names preserve the V02 report interface.
"""
from pathlib import Path
import argparse
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]


def build(root, year):
    with np.load(root / 'evidence/spatial_metadata.npz', allow_pickle=True) as meta:
        natural = np.isin(meta['class'], [10, 20, 30, 40])
        water = meta['water_fraction']
        dominant = natural & (meta['land_fraction'] >= .8) & (water == 0)
        imputed = np.array(['IMPUT' in flag for flag in meta['flags'].astype(str)])
        masks = [
            ('All terrestrial columns', np.ones(len(water), dtype=bool)),
            ('Non urban natural or crop classes', natural),
            ('Natural or crop without water majority', natural & (water <= .5)),
            ('Natural or crop dominant fraction at least 80 percent', dominant),
            ('Previous subset without imputed soil', dominant & ~imputed),
        ]
        with np.load(root / f'evidence/aggregates_{year}.npz') as data:
            rows = []
            for name, mask in masks:
                if not mask.any():
                    raise ValueError(f'Empty reporting population: {name}')
                rows.append({
                    'selection': name,
                    'cells': int(mask.sum()),
                    f'ET_aprsep_{year}_mm': float(data['ET_aprsep_cell'][mask].mean()),
                    'shallow_moisture_kg_m3': float(data['WC_aprsep_cell'][mask, 0].mean()),
                })
    return pd.DataFrame(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--year', type=int, default=2025)
    parser.add_argument('--verify', action='store_true', help='Compare all rows with the preserved CSV; do not write')
    args = parser.parse_args()
    frame = build(args.root, args.year)
    target = args.root / 'tables/representation_sensitivity.csv'
    if args.verify:
        pd.testing.assert_frame_equal(frame, pd.read_csv(target), check_exact=False, atol=1e-11, rtol=1e-13)
        print(f'PASS: all {len(frame)} populations reproduce {target.name}')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        frame.to_csv(target, index=False)
        print(f'WROTE {target}')


if __name__ == '__main__':
    main()
