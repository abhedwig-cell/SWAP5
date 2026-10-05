#!/usr/bin/env python3
"""Apply the bounded reporting-only B1 frost correction without touching its baseline."""
import hashlib,pathlib,sys
BASE = "edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf"
TARGET = "9d75dc4a552f438fa4f358f3d9e17ddaaa1d50348e549b11802617a270ca1c87"
if len(sys.argv)!=3:raise SystemExit('usage: apply.py original_frozencond output_copy')
source=pathlib.Path(sys.argv[1]);output=pathlib.Path(sys.argv[2])
if source.resolve()==output.resolve():raise SystemExit('original source overwrite forbidden')
data=source.read_bytes()
if hashlib.sha256(data).hexdigest()!=BASE:raise SystemExit('unexpected B1.11 frost source')
needle=b'            end if\r\n         else\r\n'
insert=b'            end if\r\n            ! FROST-DRAIN-01: report the actual HeadCalc nodal sink owner.\r\n            if (swdivd == 0 .and. swmacro == 0 .and. swdra == 1) then\r\n               do level=1,nrlevs\r\n                  qdrain(level) = sum(qdra(level,1:numnod))\r\n               end do\r\n            end if\r\n         else\r\n'
if data.count(needle)!=1:raise SystemExit('nonunique patch context')
target=data.replace(needle,insert)
if hashlib.sha256(target).hexdigest()!=TARGET:raise SystemExit('unexpected corrected postimage')
if output.exists() and output.read_bytes()!=target:raise SystemExit('existing output differs')
output.write_bytes(target)
print('FROST_DRAIN_01_EXACT_APPLICATOR=PASS')
