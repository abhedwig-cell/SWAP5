#!/usr/bin/env python3
from pathlib import Path
import argparse
import re

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

# Retain the complete declaration, including later production locals. Fail
# closed if the two original balance variables no longer share one declaration.
markers=re.findall(r"^   real\(8\).*:: CritDevBalCp, CritDevBalTot[^\n]*\n",src,re.M)
if len(markers)!=1:
    raise SystemExit("TIMEINT16 declaration marker missing or ambiguous")
marker=markers[0]
insert=marker+"""   integer :: timeint16_capture_origin, timeint16_origin_ready
   real(8) :: timeint16_origin_nonstorage(1000)
   common /timeint16_origin_common/ timeint16_capture_origin, timeint16_origin_ready, timeint16_origin_nonstorage
"""
src=src.replace(marker,insert,1)

# Capture the completed vector_F residual after every source/sink contribution,
# including the current typed macropore exchange, without replacing any term.
end_marker="\nend subroutine vector_F\n"
end_repl="""
   if (timeint16_capture_origin == 1 .and. timeint16_origin_ready == 0) then
      timeint16_origin_nonstorage(1:NN)=fsi_ws%residual(1:NN)
      timeint16_origin_ready=1
   end if

end subroutine vector_F
"""
if src.count(end_marker)!=1:
    raise SystemExit("TIMEINT16 vector_F marker missing or ambiguous")
src=src.replace(end_marker,end_repl,1)

for req in ("timeint16_origin_common","timeint16_origin_nonstorage(1:NN)=fsi_ws%residual(1:NN)"):
    if req not in src: raise SystemExit(f"TIMEINT16 patch failed: {req}")

Path(args.output).write_text(src)
print("F_PE_TIMEINT16_ORIGIN_CAPTURE_MATERIALIZER=PASS")
