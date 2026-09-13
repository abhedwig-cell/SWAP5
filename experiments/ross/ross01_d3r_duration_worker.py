from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import ross01_d2_fsi31_adapter_base as base


def main() -> int:
    try:
        request = json.loads(sys.stdin.read())
        forcing = request.get("forcing_process_requests") if isinstance(request, dict) else None
        if not isinstance(forcing, dict):
            raise base.RequestError("INVALID_FORCING_REQUEST", "forcing_process_requests must be an object")
        t0 = float(forcing.get("t0_day"))
        t1 = float(forcing.get("t1_day"))
        duration = t1 - t0
        if not math.isfinite(duration) or duration <= 0.0:
            raise base.RequestError("INVALID_TIME_INTERVAL", "isolated D3R worker requires a finite positive duration")
        # Parent D3R admission already restricts dt to the canonical ladder.
        # The child repeats every frozen D2 request check with that exact dt.
        base.HORIZON_DAY = duration
        base.validate_request(request)
        result = base._worker_execute(request)
    except base.RequestError as exc:
        result = base._worker_failure(exc.classification, exc.detail, "worker_preflight")
    except Exception as exc:
        result = base._worker_failure("WORKER_UNHANDLED_EXCEPTION", repr(exc), "isolated_worker")
    print(json.dumps(result, sort_keys=True, allow_nan=False))
    return 0 if result.get("solver_disposition") == "candidate_ready" else 2


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--worker":
        raise SystemExit(main())
    raise SystemExit("F-ROSS01 D3R duration worker is an isolated child entry point; use --worker only")
