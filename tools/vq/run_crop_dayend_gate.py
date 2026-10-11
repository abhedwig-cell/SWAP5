#!/usr/bin/env python3
"""Run a frozen-head existing gate and preserve its terminal control receipt."""
import datetime
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
scratch, name, runner = sys.argv[1:]
scratch = pathlib.Path(scratch)
assert name in ('dayend-full-moving', 'dayend-ppa-preservation')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


assert not git('status', '--porcelain')
assert git('rev-parse', 'HEAD:src') == 'b52c70dc50742fdbf5b03f71ec68709b191d0ec7'
before = git('rev-parse', 'HEAD')
record = {'gate': name, 'command': ['bash', runner], 'head': before,
          'tree': git('rev-parse', 'HEAD^{tree}'), 'source_tree': git('rev-parse', 'HEAD:src'),
          'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
with (scratch / (name + '.log')).open('wb') as output:
    result = subprocess.call(['bash', runner], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
record.update(terminal_exit_code=result, end_head=git('rev-parse', 'HEAD'),
              ended_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              worktree_clean_at_end=not git('status', '--porcelain'))
(scratch / (name + '.control.json')).write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
assert before == record['end_head'] and record['worktree_clean_at_end']
sys.exit(result)
