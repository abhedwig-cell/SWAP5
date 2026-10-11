#!/usr/bin/env python3
from pathlib import Path
import hashlib
import sys

root = Path(__file__).resolve().parents[2]
checks = {}

def sha(path):
    return hashlib.sha1((b"blob %d\0" % path.stat().st_size) + path.read_bytes()).hexdigest()

pins = {
    "src/transaction/mod_transaction_reference.f90": "4a573316b77252b56bcb429fd519aa57123e9a06",
    "src/adapter/mod_b1_10_temporal_characterization.f90": "dd41426fcbea2d009613050aa94988885ae24f8b",
    "src/adapter/mod_b1_10_recoverable_reference_model.f90": "e4a37554359f25efb120f55eea7465559a94938d",
}
for rel, expected in pins.items():
    p = root / rel
    checks[f"pin:{rel}"] = p.exists() and sha(p) == expected

policy = (root / "src/adapter/mod_b1_10_reference_temporal_policy.f90").read_text()
model = (root / "src/adapter/mod_b1_10_reference_policy_candidate_model.f90").read_text()

checks["no_numeric_defaults"] = policy.count("= -1.0_real64") >= 8
checks["endpoint_head"] = "delta%max_abs_h_cm" in policy
checks["endpoint_theta"] = "delta%max_abs_theta" in policy
checks["endpoint_pond"] = "delta%abs_pond_cm" in policy
checks["endpoint_gwl"] = "delta%abs_gwl_cm" in policy
checks["endpoint_volact"] = "delta%abs_volact_cm" in policy
checks["endpoint_evap_memory"] = all(x in policy for x in ("delta%abs_ldwet", "delta%abs_spev", "delta%abs_saev"))
checks["lagged_not_normalized"] = all(x not in policy.split("assessment%h_ratio =",1)[1] for x in (
    "delta%max_abs_hm1_cm", "delta%max_abs_thetm1", "delta%abs_pondm1_cm", "delta%abs_gwlm1_cm"))
checks["optional_process_fail_closed"] = "delta%process_scope_complete" in policy
checks["normalized_acceptance_threshold"] = "assessment%normalized_error <= 1.0_real64" in policy
checks["candidate_profile_unqualified"] = "qualified_numeric_profile = .false." in model
checks["candidate_reference_blocked"] = "admitted = self%qualified_numeric_profile .and. self%temporal_limits_bound" in model
checks["no_solver_tolerance_reuse"] = all(x.lower() not in (policy+model).lower() for x in (
    "critdevbalcp", "critdevbaltot", "critdevh", "dtmin", "maxit", "mass_tolerance"))
checks["no_file_io"] = all(x.lower() not in (policy+model).lower() for x in ("open(", "read(", "write(", "swp_file", "outfile"))

failed=[k for k,v in checks.items() if not v]
print({"work_unit":"F-CI14","checks":checks,"failed":failed})
if failed:
    sys.exit(1)
