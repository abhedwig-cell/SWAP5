#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python -m pytest -q test_fgc41_whole_window_acceptance_retry.py
