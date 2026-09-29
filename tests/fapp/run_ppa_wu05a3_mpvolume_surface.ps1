$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap-surface-' + [guid]::NewGuid().ToString('N'))
$outputs = @()
foreach ($opt in @('O0','O2')) {
    $dir = Join-Path $build $opt
    New-Item -ItemType Directory $dir -Force | Out-Null
    $exe = Join-Path $dir 'test.exe'
    & gfortran '-J' $dir '-I' $dir '-std=f2008' '-Wall' '-Wextra' '-Werror' '-fcheck=all' `
        '-ffpe-trap=invalid,zero,overflow' "-$opt" `
        (Join-Path $repo 'src/process/mod_ppa_wu05a3_mpvolume_surface.f90') `
        (Join-Path $repo 'tests/fapp/test_ppa_wu05a3_mpvolume_surface_source_oracle.f90') '-o' $exe
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    $result = & $exe 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $result" }
    $outputs += ,($result -join "`n")
}
if ($outputs[0] -cne $outputs[1]) { throw 'O0/O2 transcripts differ' }
$outputs[0]
'PPA_WU05A3_MPVOLUME_SURFACE_O0_O2_IDENTITY=PASS'
