#!/usr/bin/env bash
set -euo pipefail
python3 -m pytest -q tests/fgc/test_fgc42_live_whole_window_service.py
echo FGC42_WHOLE_WINDOW_SERVICE_GATE=PASS
