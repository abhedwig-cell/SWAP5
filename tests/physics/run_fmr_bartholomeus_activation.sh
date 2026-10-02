#!/usr/bin/env bash
set -euo pipefail
FC="${FC:-gfortran}";B="${TMPDIR:-/tmp}/ppa_wu05c3a";rm -rf "$B";mkdir -p "$B"
cat > "$B/mod_bartholomeus_waterfilm_provider.f90" <<'EOF'
module mod_bartholomeus_waterfilm_provider
 integer,parameter::BARTHOLOMEUS_WATERFILM_REFERENCE=1
end module
EOF
"$FC" -std=f2008 -Wall -Wextra -Werror -J"$B" -I"$B" -c "$B/mod_bartholomeus_waterfilm_provider.f90" -o "$B/w.o"
"$FC" -std=f2008 -Wall -Wextra -Werror -J"$B" -I"$B" -c src/runtime/mod_fmr_bartholomeus_activation.f90 -o "$B/a.o"
"$FC" -std=f2008 -Wall -Wextra -Werror -J"$B" -I"$B" tests/physics/test_fmr_bartholomeus_activation.f90 "$B/a.o" "$B/w.o" -o "$B/test"
"$B/test"
