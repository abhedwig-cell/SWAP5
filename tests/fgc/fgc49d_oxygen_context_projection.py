"""Build a private, trampoline-free oxygen candidate from the incumbent sources."""

from pathlib import Path
import re
import sys


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"Expected exactly one source anchor: {old!r}")
    return source.replace(old, new)


def project(source_dir, output_dir):
    bracket_path = source_dir / "mod_oxygen_scalar_bracket.f90"
    bracket = bracket_path.read_text(encoding="utf-8")
    start = bracket.index("   subroutine oxygen_bisect_monotone(")
    end = bracket.index("\nend module", start)
    context = bracket[start:end].replace("oxygen_bisect_monotone", "oxygen_bisect_context")
    context = replace_once(context, "(residual, xmax", "(residual, context, xmax")
    context = replace_once(
        context, "procedure(oxygen_residual) :: residual",
        "procedure(oxygen_context_residual) :: residual\n      class(*), intent(inout) :: context",
    )
    for point in ("a", "b", "mid"):
        context = replace_once(context, f"residual({point})", f"residual({point}, context)")
    bracket = replace_once(bracket, "   end interface", """      function oxygen_context_residual(x, context) result(f)
         import real64
         real(real64), intent(in) :: x
         class(*), intent(inout) :: context
         real(real64) :: f
      end function oxygen_context_residual
   end interface""")
    bracket = replace_once(bracket, "public :: oxygen_bisect_monotone",
                           "public :: oxygen_bisect_monotone, oxygen_bisect_context")
    bracket = replace_once(bracket, "\nend module", "\n" + context + "\nend module")

    response_path = source_dir / "mod_bartholomeus_response.f90"
    response = response_path.read_text(encoding="utf-8")
    response = replace_once(response, "only : oxygen_bisect_monotone,", "only : oxygen_bisect_context,")
    response = replace_once(response, "\ncontains\n", """
   type :: ResponseContext
      type(BartholomeusResponseInput) :: input
      logical :: residual_valid
   end type ResponseContext

contains
""")
    response = replace_once(response, "      logical :: residual_valid\n\n      ok",
                            "      type(ResponseContext) :: context\n\n      ok")
    response = replace_once(response, "      residual_valid = .true.",
                            "      context%input = p\n      context%residual_valid = .true.")
    response = replace_once(response, "oxygen_bisect_monotone(residual, p%",
                            "oxygen_bisect_context(residual, context, p%")
    response = replace_once(response, "if (.not. residual_valid)", "if (.not. context%residual_valid)")
    start = response.index("   contains\n      function residual")
    end = response.index("\n\n   pure function", start)
    callback = re.fullmatch(
        r"   contains\n      function residual\(x\) result\(f\)\n(.*?)"
        r"      end function residual\n   end subroutine bartholomeus_respiration_factor",
        response[start:end], re.S,
    )
    if callback is None:
        raise ValueError("Unexpected incumbent residual layout")
    declarations, body = callback[1].split("\n\n", 1)
    body = body.replace("p%", "context%input%").replace("residual_valid", "context%residual_valid")
    response = response[:start] + (
        "   end subroutine bartholomeus_respiration_factor\n\n"
        "   function residual(x, context) result(f)\n"
        "      class(*), intent(inout) :: context\n"
        + "\n".join(line[3:] for line in declarations.splitlines())
        + "\n\n      select type(context)\n      type is (ResponseContext)\n"
        + body
        + "      class default\n         error stop 'Invalid private oxygen response context'\n"
        "      end select\n   end function residual"
    ) + response[end:]

    output_dir.mkdir(parents=True, exist_ok=True)
    for path, contents in ((bracket_path, bracket), (response_path, response)):
        with (output_dir / path.name).open("x", encoding="utf-8") as target:
            target.write(contents)


if __name__ == "__main__":
    project(Path(sys.argv[1]), Path(sys.argv[2]))
