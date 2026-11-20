"""Run the unchanged Frost composition harness with explicit implicit inputs."""
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import frost_cde_drainage_runtime as existing


def main():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument('--existing-input', type=Path)
    args, _ = p.parse_known_args()
    if args.existing_input:
        sys.path.insert(0, str(existing.ROOT/'app/hybrid_water'))
        from experimental_project import switches
        if switches((args.existing_input/'swap.swp').read_text(encoding='cp1252')).get('SWKIMPL') != 1:
            raise ValueError('Existing Frost implicit input must actually select SWKIMPL1')
    original_fixture = existing.thermal.fixture

    def fixture(destination, case, precision):
        original_fixture(destination, case, precision)
        path = destination/'swap.swp'
        path.write_text(existing.assignment(path.read_text(encoding='cp1252'), 'SWKIMPL', 1), encoding='cp1252')

    existing.thermal.fixture = fixture
    existing.main()


if __name__ == '__main__': main()
