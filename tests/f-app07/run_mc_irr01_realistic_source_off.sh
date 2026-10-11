#!/usr/bin/env bash
set -euo pipefail
MC_IRR01_EVENT_PHASE=off bash "$(dirname "${BASH_SOURCE[0]}")/run_mc_irr01_realistic_event.sh"
