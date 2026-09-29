$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$build=Join-Path $env:TEMP ('swap-mvg-difference-'+[guid]::NewGuid())
$outputs=@{}
foreach($opt in 0,2) {
    $out=Join-Path $build "O$opt"
    New-Item -ItemType Directory $out | Out-Null
    $exe=Join-Path $out 'test.exe'
    & gfortran -std=f2008 -Wall -Wextra -fcheck=all '-ffpe-trap=invalid,zero,overflow' "-O$opt" -J $out -I $out `
        (Join-Path $repo 'src/solver/mod_soil_water_solver_contract.f90') `
        (Join-Path $repo 'src/solver/mod_b110_default_mvg_provider.f90') `
        (Join-Path $repo 'src/solver/mod_ppa_mvg_storage_difference.f90') `
        (Join-Path $repo 'src/adapter/mod_ppa_mvg_storage_binding.f90') `
        (Join-Path $PSScriptRoot 'test_ppa_mvg_storage_difference.f90') -o $exe
    if($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    $outputs[$opt]=@(& $exe)
    if($LASTEXITCODE -ne 0) { throw "Oracle failed O$opt" }
    if(($outputs[$opt] -join "`n") -notmatch 'MVG_STORAGE_QUAD_ORACLE=PASS') { throw 'Missing oracle marker' }
    $outputs[$opt]
}
if(($outputs[0] -join "`n") -cne ($outputs[2] -join "`n")) { throw 'Optimization transcript mismatch' }
'MVG_STORAGE_O0_O2_IDENTITY=PASS'
"BUILD=$build"
