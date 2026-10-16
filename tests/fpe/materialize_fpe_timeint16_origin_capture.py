#!/usr/bin/env python3
from pathlib import Path
import argparse

ap=argparse.ArgumentParser()
ap.add_argument("--source",required=True)
ap.add_argument("--output",required=True)
args=ap.parse_args()

src=Path(args.source).read_text()

marker="   real(8)                          :: CritDevBalCp, CritDevBalTot\n"
insert=marker+"""   integer :: timeint16_capture_origin, timeint16_origin_ready
   real(8) :: timeint16_origin_nonstorage(1000)
   common /timeint16_origin_common/ timeint16_capture_origin, timeint16_origin_ready, timeint16_origin_nonstorage
"""
if marker not in src:
    raise SystemExit("TIMEINT16 declaration marker missing")
src=src.replace(marker,insert,1)

end_marker="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

end subroutine vector_F
"""
end_repl="""   if (swmacro == 1) fsi_ws%residual(1:NN) = fsi_ws%residual(1:NN) - QExcMpMtx(1:NN)

   if (timeint16_capture_origin == 1 .and. timeint16_origin_ready == 0) then
      timeint16_origin_nonstorage(1:NN)=fsi_ws%residual(1:NN)
      timeint16_origin_ready=1
   end if

end subroutine vector_F
"""
if end_marker not in src:
    raise SystemExit("TIMEINT16 vector_F marker missing")
src=src.replace(end_marker,end_repl,1)

for req in ("timeint16_origin_common","timeint16_origin_nonstorage(1:NN)=fsi_ws%residual(1:NN)"):
    if req not in src: raise SystemExit(f"TIMEINT16 patch failed: {req}")

Path(args.output).write_text(src)
print("F_PE_TIMEINT16_ORIGIN_CAPTURE_MATERIALIZER=PASS")
