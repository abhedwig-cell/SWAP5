"""Run the unchanged Frost composition harness with explicit implicit inputs."""
import argparse
from pathlib import Path
import re
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
        text = path.read_text(encoding='cp1252')
        for key, value in dict(SWKIMPL=1, MAXIT=100, MAXBACKTR=10).items():
            text = existing.assignment(text, key, value)

        def fitted_ksat(match):
            names = match[1].split(); rows = []
            for line in match[2].splitlines():
                fields = line.split()
                assert len(fields) == len(names)
                fields[names.index('KSATEXM')] = fields[names.index('KSATFIT')]
                rows.append(' '.join(fields))
            return match[1] + '\n'.join(rows) + '\n* End of table'

        text, count = re.subn(r'(?mi)^([ \t]*ORES[ \t]+OSAT[^\r\n]*\n)(.*?)^\* End of table',
                             fitted_ksat, text, count=1, flags=re.S)
        assert count == 1, 'Missing original named fitted-Ksat parameter table'
        path.write_text(text, encoding='cp1252')

    existing.thermal.fixture = fixture
    existing.main()


if __name__ == '__main__': main()
