$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-tcsfix-composition-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $build | Out-Null
$sources = @('src/solver/mod_soil_water_solver_contract.f90', 'src/solver/mod_process_hydraulic_view.f90',
 'src/process/mod_irrigation_process.f90', 'src/process/mod_ppa_irr_tcs1_4_timing.f90',
 'src/process/mod_ppa_irr_tcsfix_filter.f90', 'src/process/mod_ppa_irr_tcsfix_composition.f90',
 'src/process/mod_ppa_irr_tcsfix_identity.f90',
 'tests/fapp/test_ppa_irr_tcsfix_composition.f90') | ForEach-Object { Join-Path $repo $_ }
foreach ($opt in @('O0','O2')) {
 & gfortran -std=f2008 -ffree-line-length-none -fcheck=all '-ffpe-trap=invalid,zero,overflow' "-$opt" -J $build -I $build @sources -o "$build/$opt.exe"
 if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $opt" }
 & "$build/$opt.exe" > "$build/$opt.txt"
 if ($LASTEXITCODE -ne 0) { throw "Composition failed: $opt" }
}
if ((Get-Content "$build/O0.txt" -Raw) -cne (Get-Content "$build/O2.txt" -Raw)) { throw 'Transcript mismatch' }
Get-Content "$build/O2.txt"
Write-Output 'PPA_IRR_TCSFIX_COMPOSITION_O0_O2_IDENTITY=PASS'
Write-Output "Build artifacts retained at $build"
