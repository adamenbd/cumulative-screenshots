$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
$automation = [System.Management.Automation.PSObject].Assembly.Location
$source = Join-Path $PSScriptRoot 'src\App.ps1'
$launcher = Join-Path $PSScriptRoot 'src\Launcher.cs'
$outputDirectory = Join-Path $PSScriptRoot 'bin'
[void][IO.Directory]::CreateDirectory($outputDirectory)
$output = Join-Path $outputDirectory 'CumulativeScreenshots.exe'
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
& $compiler /nologo /target:winexe "/out:$output" "/resource:$source,App.ps1" "/reference:$automation" /reference:System.Windows.Forms.dll $launcher
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Close the running executable before rebuilding.' }
Write-Output "Built $output"
