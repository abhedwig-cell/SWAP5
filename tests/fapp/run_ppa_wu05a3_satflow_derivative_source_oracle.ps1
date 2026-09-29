$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$build = Join-Path ([IO.Path]::GetTempPath()) ('swap5-satflow-derivative-' + [guid]::NewGuid().ToString('N'))
$outputs = @()
foreach ($optimization in @('O0', 'O2')) {
    $directory = Join-Path $build $optimization
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $executable = Join-Path $directory 'oracle.exe'
    & gfortran '-J' $directory '-I' $directory '-std=f2008' '-Wall' '-Wextra' '-Werror' `
        '-fcheck=all' '-ffpe-trap=invalid,zero,overflow' "-$optimization" `
        (Join-Path $repo 'src/process/mod_ppa_wu05a3_satflow_derivative.f90') `
        (Join-Path $repo 'tests/fapp/test_ppa_wu05a3_satflow_derivative_source_oracle.f90') '-o' $executable
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $optimization" }
    $result = & $executable 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $optimization : $result" }
    $outputs += ,($result -join "`n")
}
if ($outputs[0] -cne $outputs[1]) { throw 'O0/O2 transcripts differ' }
$outputs[0]
'PPA_WU05A3_SATFLOW_DERIVATIVE_O0_O2_IDENTITY=PASS'
