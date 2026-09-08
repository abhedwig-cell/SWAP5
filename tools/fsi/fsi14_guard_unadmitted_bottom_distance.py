#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = Path('src/legacy/b1_10_port/headcalc.f90')
EXPECTED = 'f0bc08fe3884ca7b7744f6285ffd7a3c9b40b4e1'
actual = subprocess.check_output(['git','hash-object',str(PATH)], text=True).strip()
if actual != EXPECTED:
    raise SystemExit(f'F-SI14 HeadCalc repair preimage mismatch: {actual} != {EXPECTED}')

s = PATH.read_text()
old = '''   if (iTask == 1) then\n      if (swbotb == 8 .AND. state%h(NN) >  Critdz - grid_disnod(NN+1) + hplate) then\n         fsi_ws%head_gradient(NN+1) = (state%h(NN) - hplate) / grid_disnod(NN+1) + 1.0d0\n         flboth = .TRUE.\n      else\n         flboth = .FALSE.\n      end if\n   else\n'''
new = '''   if (iTask == 1) then\n      if (swbotb == 8) then\n         if (state%h(NN) > Critdz - grid_disnod(NN+1) + hplate) then\n            fsi_ws%head_gradient(NN+1) = (state%h(NN) - hplate) / grid_disnod(NN+1) + 1.0d0\n            flboth = .TRUE.\n         else\n            flboth = .FALSE.\n         end if\n      else\n         flboth = .FALSE.\n      end if\n   else\n'''
if s.count(old) != 1:
    raise SystemExit(f'F-SI14 unadmitted bottom-distance guard marker count={s.count(old)}')
PATH.write_text(s.replace(old,new,1))
print('F-SI14_UNADMITTED_BOTTOM_DISTANCE_GUARD_MATERIALIZATION PASS')
