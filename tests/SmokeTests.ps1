# Testes rápidos do Win10 Emoji Refresh (sem alterar o sistema).
param([string]$FontFile)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..\src\Win11Emoji.ps1'
$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) {
        Write-Host "  PASS  $Message" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  FAIL  $Message" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host 'Win10 Emoji Refresh - smoke tests' -ForegroundColor Cyan

# 1. O script principal compila/analisa sem erros de sintaxe.
$tokens = $null; $errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors)
Assert-True ($errors.Count -eq 0) "analise sintatica de Win11Emoji.ps1 ($($errors.Count) erros)"

# 1b. O normalizador de fila e o codigo do setup devem existir e compilar.
$fixPending = Join-Path $PSScriptRoot '..\src\FixPending.ps1'
Assert-True (Test-Path -LiteralPath $fixPending) 'src/FixPending.ps1 existe'
$fixTokens = $null; $fixErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($fixPending, [ref]$fixTokens, [ref]$fixErrors)
Assert-True ($fixErrors.Count -eq 0) "analise sintatica de FixPending.ps1 ($($fixErrors.Count) erros)"

$setupSource = Join-Path $PSScriptRoot '..\src\Setup\Program.cs'
$setupBuilder = Join-Path $PSScriptRoot '..\src\Setup\build.ps1'
Assert-True (Test-Path -LiteralPath $setupSource) 'codigo-fonte do setup existe'
Assert-True (Test-Path -LiteralPath $setupBuilder) 'script de build do setup existe'

# 2. Diagnostico deve funcionar e identificar o Windows 10.
$diag = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Diagnose -Json 2>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0) 'diagnostico -Json retorna 0'
Assert-True ($diag -match '"product"\s*:\s*"Win10EmojiRefresh"') 'diagnostico contem o produto'
Assert-True ($diag -match '"currentBuild"') 'diagnostico contem o build'
Assert-True ($diag -match '"panelFontSource"') 'diagnostico informa a fonte do painel Win+.'
Assert-True ($diag -match '"panelFollowsUserOverride"\s*:\s*false') 'diagnostico marca que painel nao segue override HKCU'
Assert-True ($diag -notmatch '^ERROR:') 'diagnostico sem ERRO'

# 3. Fonte de teste, se disponivel, deve ser validada.
if (-not $FontFile) {
    $FontFile = 'C:\Users\Honeymoon\AppData\Local\Temp\opencode\seguiemj-win11.ttf'
}
if (Test-Path -LiteralPath $FontFile) {
    $dry = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script `
        -Mode User -Force -DryRun -Source $FontFile 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0) 'dry-run com fonte local retorna 0'
    Assert-True ($dry -match 'Version 1\.60') 'dry-run identifica a versao 1.60'
    Assert-True ($dry -match '62354') 'dry-run identifica 62354 glifos'
    Assert-True ($dry -match 'DRY RUN: nothing was changed') 'dry-run nao altera nada'
} else {
    Write-Host "  SKIP  fonte de teste nao encontrada: $FontFile" -ForegroundColor DarkGray
}

# 4. Setup de release, quando ja compilado, deve conter os scripts embutidos.
$setupExe = Join-Path $PSScriptRoot '..\release\Win10EmojiRefresh-Setup.exe'
if (Test-Path -LiteralPath $setupExe) {
    $asm = [Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $setupExe).Path)
    $names = @($asm.GetManifestResourceNames())
    Assert-True ($names -contains 'Win11Emoji.ps1') 'setup embute Win11Emoji.ps1'
    Assert-True ($names -contains 'FixPending.ps1') 'setup embute FixPending.ps1'

    $help = & $setupExe --help 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0) 'setup --help retorna 0'
    Assert-True ($help -match 'No Microsoft font is included in this executable') 'setup declara que nao embute a fonte'
    Assert-True ($help -match 'Usage:') 'setup --help esta em ingles'
    Assert-True ($help -match 'Win10 Emoji Refresh - release setup') 'setup usa o nome novo'

    $res = $asm.GetManifestResourceStream('Win11Emoji.ps1')
    $reader = New-Object IO.StreamReader($res)
    $embedded = $reader.ReadToEnd()
    $reader.Dispose()
    Assert-True ($embedded -match 'DRY RUN: nothing was changed') 'script embutido esta em ingles'
    Assert-True ($embedded -notmatch 'nada foi alterado') 'script embutido nao contem mensagens em portugues'
} else {
    Write-Host "  SKIP  setup.exe ainda nao foi compilado" -ForegroundColor DarkGray
}

Write-Host ''
Write-Host "Resultado: $passed passou, $failed falhou" -ForegroundColor $(if ($failed) { 'Red' } else { 'Green' })
if ($failed) { exit 1 }
exit 0
