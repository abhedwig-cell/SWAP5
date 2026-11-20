"""Project the serialized selectors into explicit, invocation-local context."""

from pathlib import Path
import re
import sys

from fgc49d_oxygen_context_projection import replace_once


def project(root, output):
    paths = (
        "runtime/mod_canonical_interval_runtime.f90",
        "kernel/mod_kernel_transactions.f90",
        "runtime/mod_fmr_checkpoint_orchestrator.f90",
    )
    for path in paths:
        source = (root / path).read_text(encoding="utf-8")
        source, count = re.subn(r", target_selector\)$", ", target_selector, selector_context)", source, flags=re.M)
        if count != (1 if path == paths[0] else 2):
            raise ValueError(f"Unexpected selector forwarding seams in {path}: {count}")
        declaration = "    procedure(canonical_subinterval_target_selector), optional :: target_selector"
        source = replace_once(source, declaration, declaration + "\n    class(*), optional, intent(inout) :: selector_context")
        if path == paths[0]:
            anchor = "      import :: real64"
            source = replace_once(source, anchor, anchor + ", canonical_physical_model_t\n"
                                  "      class(canonical_physical_model_t), intent(inout) :: model\n"
                                  "      class(*), intent(inout) :: selector_context")
            source = replace_once(source, "canonical_subinterval_target_selector(cursor,",
                                  "canonical_subinterval_target_selector(model, selector_context, cursor,")
            source = replace_once(source, "    if (config%retain_accepted_step_proposal) then", """    if (present(target_selector) .neqv. present(selector_context)) then
      result%status = CANONICAL_STATUS_INVALID_REQUEST
      return
    end if

    if (config%retain_accepted_step_proposal) then""")
            source = replace_once(source, "call target_selector(cursor,",
                                  "call target_selector(model, selector_context, cursor,")
        write(output, path, source)

    path = "runtime/mod_fmr_serialized_reference_backend.f90"
    source = (root / path).read_text(encoding="utf-8")
    header = "module mod_fmr_serialized_reference_backend\n"
    if not source.startswith(header):
        raise ValueError("Unexpected serialized backend module header")
    source = header + "  use mod_canonical_contracts, only: canonical_physical_model_t\n" + source[len(header):]
    source = replace_once(source, "  end type fmr_serialized_reference_backend_t", """  end type fmr_serialized_reference_backend_t

  type :: proposal_selector_context_t
    integer :: max_retries
    real(real64) :: progress_tolerance, previous_cursor
    logical :: anchored_ceiling
  end type proposal_selector_context_t""")
    source = replace_once(source, "    real(real64) :: previous_selector_cursor,accepted_width,endpoint_margin",
                          "    type(proposal_selector_context_t) :: selector_context")
    source = replace_once(source, "    previous_selector_cursor=t0", """    selector_context%previous_cursor = t0
    selector_context%anchored_ceiling = anchored_ceiling
    selector_context%max_retries = config%transaction%max_retries
    selector_context%progress_tolerance = config%progress_tolerance""")
    for name in ("select_hbot5_proposal", "select_cauchy3_proposal"):
        source = replace_once(source, f"target_selector={name})",
                              f"target_selector={name}, selector_context=selector_context)")
    start = source.index("  contains\n    subroutine select_hbot5_proposal")
    end_marker = "  end subroutine fmr_serialized_backend_run_trial"
    end = source.index(end_marker, start)
    callbacks = source[start:end].removeprefix("  contains\n")

    def lift(match):
        name, declarations, body = match.groups()
        declarations += "      real(real64) :: accepted_width, endpoint_margin\n" if "cauchy3" in name else ""
        body = body.replace("self%model%", "model%")
        body = body.replace("config%transaction%max_retries", "context%max_retries")
        body = body.replace("config%progress_tolerance", "context%progress_tolerance")
        body = body.replace("anchored_ceiling", "context%anchored_ceiling")
        body = body.replace("previous_selector_cursor", "context%previous_cursor")
        return (
            f"  subroutine {name}(model, context, cursor, requested_t1, target_t1, max_retries_cap, valid)\n"
            "    class(canonical_physical_model_t), intent(inout) :: model\n"
            "    class(*), intent(inout) :: context\n"
            + "".join(line[2:] for line in declarations.splitlines(keepends=True))
            + "    valid = .false.\n    target_t1 = requested_t1\n    max_retries_cap = 0\n"
            "    select type(model)\n    type is (fmr_serialized_reference_model_t)\n"
            "    select type(context)\n    type is (proposal_selector_context_t)\n"
            + body + "    end select\n    end select\n"
            f"  end subroutine {name}"
        )

    callbacks, count = re.subn(
        r"    subroutine (select_\w+_proposal)\([^\n]+\)\n"
        r"(.*?      integer :: provider_status\n)(.*?)    end subroutine",
        lift, callbacks, flags=re.S,
    )
    if count != 2:
        raise ValueError("Expected both incumbent proposal selectors")
    source = source[:start] + end_marker + "\n\n" + callbacks + source[end + len(end_marker):]
    write(output, path, source)


def write(output, path, source):
    destination = output / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("x", encoding="utf-8") as stream:
        stream.write(source)


if __name__ == "__main__":
    project(Path(sys.argv[1]), Path(sys.argv[2]))
