"""Compare existing complete observer streams; impose no new acceptance tolerance."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def compare(left, right):
    a = json.loads(left.read_text())
    b = json.loads(right.read_text())
    assert a.keys() == b.keys(), 'observer schema differs'
    result = {}
    for key in a:
        assert len(a[key]) == len(b[key]), (key, 'period differs')
        largest = dict(absolute=0.0, day=None, slot=None)
        first = None
        for day, (x, y) in enumerate(zip(a[key], b[key])):
            assert len(x) == len(y), (key, day, 'grid differs')
            for slot, (u, v) in enumerate(zip(x, y)):
                assert math.isfinite(u) and math.isfinite(v)
                difference = abs(u-v)
                if difference and first is None:
                    first = day
                if difference > largest['absolute']:
                    largest = dict(absolute=difference, day=day, slot=slot,
                                   left=u, right=v)
        result[key] = dict(rows=len(a[key]), first_nonzero_day=first,
                           maximum=largest)
    return dict(left_sha256=hashlib.sha256(left.read_bytes()).hexdigest(),
                right_sha256=hashlib.sha256(right.read_bytes()).hexdigest(),
                fields=result)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--left', type=Path, required=True)
    p.add_argument('--right', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    result = {'disposition': 'DESCRIPTIVE_NO_NEW_ACCEPTANCE_CRITERION',
              'left': str(a.left), 'right': str(a.right), 'projects': {}}
    for project in ('grass', 'hupsel', 'saltfarm'):
        modes = {}
        for mode in ('original', 'corrected-daily', 'corrected-coherent'):
            sub = Path(project+'-coherent')/mode/'FRAMES.json'
            modes[mode] = compare(a.left/sub, a.right/sub)
        result['projects'][project] = modes
    a.output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
