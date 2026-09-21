"""Validator for the DUMMY-18 real-model authority map."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


ALLOWED_STATUSES = {"BOUND", "NON_EQUIVALENT", "UNRESOLVED"}
ALLOWED_CLASSES = {
    "STATE",
    "TRANSFER",
    "MANAGEMENT_DECISION",
    "CLOCK",
    "TRANSACTION",
    "DIAGNOSTIC",
}
ALLOWED_STAGE_STATES = {"READY_RESTRICTED", "BLOCKED"}


def load_authority_map(path: str | Path) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def index_rows(data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {row["id"]: row for row in data["rows"]}


def validate_authority_map(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []

    rows = data.get("rows")
    if not isinstance(rows, list) or not rows:
        return ["rows must be a non-empty list"]

    ids: list[str] = []
    for row in rows:
        row_id = row.get("id")
        if not isinstance(row_id, str) or not row_id:
            errors.append("every row requires a non-empty id")
            continue
        ids.append(row_id)

        status = row.get("status")
        row_class = row.get("class")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{row_id}: invalid status {status!r}")
        if row_class not in ALLOWED_CLASSES:
            errors.append(f"{row_id}: invalid class {row_class!r}")

        if not row.get("component"):
            errors.append(f"{row_id}: component is required")
        if not row.get("analytical"):
            errors.append(f"{row_id}: analytical object is required")
        if not row.get("real"):
            errors.append(f"{row_id}: real object is required")
        if not row.get("time_support"):
            errors.append(f"{row_id}: time_support is required")
        if not row.get("comparison_rule"):
            errors.append(f"{row_id}: comparison_rule is required")

        substitution_allowed = row.get("substitution_allowed")
        authority = row.get("authority")

        if status == "BOUND":
            if substitution_allowed is not True:
                errors.append(
                    f"{row_id}: BOUND row must be substitution_allowed"
                )
            if not isinstance(authority, list) or not authority:
                errors.append(f"{row_id}: BOUND row requires authority evidence")
            if row.get("blocker"):
                errors.append(f"{row_id}: BOUND row must not have blocker")
        elif status == "NON_EQUIVALENT":
            if substitution_allowed is not False:
                errors.append(
                    f"{row_id}: NON_EQUIVALENT row cannot be substitution_allowed"
                )
            if not row.get("adaptation_required"):
                errors.append(
                    f"{row_id}: NON_EQUIVALENT row requires adaptation_required"
                )
            if not isinstance(authority, list) or not authority:
                errors.append(
                    f"{row_id}: NON_EQUIVALENT row requires authority evidence"
                )
        elif status == "UNRESOLVED":
            if substitution_allowed is not False:
                errors.append(
                    f"{row_id}: UNRESOLVED row cannot be substitution_allowed"
                )
            if not row.get("blocker"):
                errors.append(f"{row_id}: UNRESOLVED row requires blocker")
            if not isinstance(authority, list) or not authority:
                errors.append(
                    f"{row_id}: UNRESOLVED row requires authority evidence"
                )

    if len(ids) != len(set(ids)):
        errors.append("row ids must be unique")

    row_index = {row["id"]: row for row in rows if row.get("id")}

    required_unresolved = data.get("required_unresolved_ids", [])
    for row_id in required_unresolved:
        row = row_index.get(row_id)
        if row is None:
            errors.append(f"required unresolved row missing: {row_id}")
        elif row.get("status") != "UNRESOLVED":
            errors.append(
                f"required unresolved row promoted without authority: {row_id}"
            )

    stages = data.get("substitution_stages")
    if not isinstance(stages, list) or not stages:
        errors.append("substitution_stages must be a non-empty list")
        return errors

    stage_ids: list[str] = []
    for stage in stages:
        stage_id = stage.get("id")
        if not isinstance(stage_id, str) or not stage_id:
            errors.append("every substitution stage requires an id")
            continue
        stage_ids.append(stage_id)

        state = stage.get("state")
        if state not in ALLOWED_STAGE_STATES:
            errors.append(f"{stage_id}: invalid stage state {state!r}")

        requirements = stage.get("requirements")
        if not isinstance(requirements, list) or not requirements:
            errors.append(f"{stage_id}: requirements must be non-empty")
            continue

        missing = [x for x in requirements if x not in row_index]
        for row_id in missing:
            errors.append(f"{stage_id}: missing requirement row {row_id}")

        if state == "READY_RESTRICTED":
            for row_id in requirements:
                row = row_index.get(row_id)
                if row and row.get("status") != "BOUND":
                    errors.append(
                        f"{stage_id}: READY stage depends on non-BOUND row "
                        f"{row_id} ({row.get('status')})"
                    )
            if stage.get("blockers"):
                errors.append(f"{stage_id}: READY stage must not have blockers")

        if state == "BLOCKED":
            blockers = stage.get("blockers")
            if not isinstance(blockers, list) or not blockers:
                errors.append(f"{stage_id}: BLOCKED stage requires blockers")
            else:
                for row_id in blockers:
                    row = row_index.get(row_id)
                    if row is None:
                        errors.append(
                            f"{stage_id}: blocker row does not exist: {row_id}"
                        )
                    elif row.get("status") == "BOUND":
                        errors.append(
                            f"{stage_id}: blocker cannot already be BOUND: "
                            f"{row_id}"
                        )
                    if row_id not in requirements:
                        errors.append(
                            f"{stage_id}: blocker must also be a requirement: "
                            f"{row_id}"
                        )

    if len(stage_ids) != len(set(stage_ids)):
        errors.append("substitution stage ids must be unique")

    pins = data.get("pins", {})
    for pin in (
        "swap5_canonical",
        "ribasim",
        "imod_coupler_inspected",
        "live_csr_candidate",
    ):
        if not pins.get(pin):
            errors.append(f"missing required source pin: {pin}")

    return errors
