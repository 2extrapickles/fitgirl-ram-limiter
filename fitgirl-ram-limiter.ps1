# FitGirl RAM Limiter by 2extrapickles

param([string]$Limit, [string]$Setup)

$ErrorActionPreference = 'Stop'
$AppName = 'FitGirl RAM Limiter by 2extrapickles'
$host.UI.RawUI.WindowTitle = $AppName

$presets = @{
    '2' = @{ Srep = 512;  Precomp = 128; Cls = 1024 }
    '4' = @{ Srep = 2048; Precomp = 256; Cls = 2048 }
    '8' = @{ Srep = 5120; Precomp = 512; Cls = 4096 }
}

function Exit-WithMessage([string]$msg) {
    Write-Host $msg -ForegroundColor Red
    Read-Host 'Press Enter to exit'
    exit 1
}

if (-not $Setup) { $Setup = Join-Path $PSScriptRoot 'setup.exe' }
if (-not [IO.File]::Exists($Setup)) { Exit-WithMessage "setup.exe not found: $Setup`nPut this tool next to the repack's setup.exe." }

if (-not $Limit) {
    Write-Host ''
    Write-Host $AppName -ForegroundColor Cyan
    Write-Host "Setup: $Setup"
    Write-Host ''
    Write-Host '  2) Limit to 2 GB'
    Write-Host '  4) Limit to 4 GB'
    Write-Host '  8) Limit to 8 GB'
    Write-Host '  0) No limit (run setup normally)'
    $Limit = (Read-Host 'Choose').Trim()
}
if ($Limit -notin @('0', '2', '4', '8')) { Exit-WithMessage "Invalid choice '$Limit'." }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Limit', $Limit, '-Setup', "`"$Setup`"")
    exit
}

function Start-Setup {
    $si = New-Object Diagnostics.ProcessStartInfo $Setup
    $si.WorkingDirectory = [IO.Path]::GetDirectoryName($Setup)
    $si.UseShellExecute = $true
    [Diagnostics.Process]::Start($si)
}

if ($Limit -eq '0') { $null = Start-Setup; exit }
$p = $presets[$Limit]

function ConvertTo-Mb([string]$value) {
    if ($value.Trim() -match '^(\d+)\s*([kmg]?)b?$') {
        $n = [double]$Matches[1]
        switch ($Matches[2].ToLower()) { 'k' { return $n / 1024 } 'g' { return $n * 1024 } default { return $n } }
    }
    return $null
}

function Get-Rule([string]$section, [string]$key) {
    if ($section -ieq 'Srep' -and $key -ieq 'Memory') { return @{ Mb = $p.Srep; Text = "$($p.Srep)m" } }
    if ($section -ieq 'Precomp' -and $key -ieq 'Memory') { return @{ Mb = $p.Precomp; Text = "$($p.Precomp)" } }
    if ($key -ieq 'MaxMemoryUsage' -or $key -ieq 'ldmfMaxMemoryUsage') { return @{ Mb = $p.Cls; Text = "$($p.Cls)m" } }
    return $null
}

function Limit-ClsIni([string]$text) {
    $lines = $text -split "`r?`n"
    $section = ''
    $changes = @()
    $limitable = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*\[(.+)\]\s*$') { $section = $Matches[1].Trim(); continue }
        if ($line -notmatch '^\s*([^=;]+?)\s*=\s*(.*?)\s*$') { continue }
        $key = $Matches[1]; $value = $Matches[2]
        $rule = Get-Rule $section $key
        if (-not $rule) { continue }
        $limitable++
        $current = ConvertTo-Mb $value
        if ($null -ne $current -and $current -le $rule.Mb) { continue }
        $lines[$i] = "$key=$($rule.Text)"
        $changes += "[$section] $key`: $value -> $($rule.Text)"
    }
    [pscustomobject]@{ Text = ($lines -join "`r`n"); Changes = $changes; Limitable = $limitable; Sections = ([regex]::Matches($text, '(?m)^\s*\[(.+?)\]') | ForEach-Object { $_.Groups[1].Value }) }
}

$tempRoot = [IO.Path]::GetTempPath()
$before = @(Get-ChildItem -LiteralPath $tempRoot -Directory -Filter 'is-*.tmp' -ErrorAction SilentlyContinue | ForEach-Object FullName)

Write-Host ''
Write-Host $AppName -ForegroundColor Cyan
Write-Host "Starting setup with a $Limit GB limit. Leave this window open until the installation finishes."
$proc = Start-Setup

$seen = @{}
while (-not $proc.HasExited) {
    $dirs = Get-ChildItem -LiteralPath $tempRoot -Directory -Filter 'is-*.tmp' -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.FullName }
    foreach ($d in $dirs) {
        $ini = Join-Path $d.FullName 'CLS.ini'
        if (-not [IO.File]::Exists($ini)) { continue }
        try {
            $text = [IO.File]::ReadAllText($ini)
            $r = Limit-ClsIni $text
            if (-not $seen.ContainsKey($ini)) {
                $seen[$ini] = $true
                Write-Host ''
                Write-Host "Found decompressor config: $ini"
                Write-Host "Compressor sections: $($r.Sections -join ', ')"
                if ($r.Limitable -eq 0) {
                    Write-Host 'This setup has no memory settings the limiter can change, so it will have no effect here.' -ForegroundColor Yellow
                } elseif ($r.Changes.Count -eq 0) {
                    Write-Host 'All memory settings are already at or below the chosen limit.' -ForegroundColor Green
                }
                foreach ($c in $r.Changes) { Write-Host "  $c" -ForegroundColor Green }
            }
            if ($r.Text -ne $text) { [IO.File]::WriteAllText($ini, $r.Text, [Text.Encoding]::ASCII) }
        } catch { }
    }
    Start-Sleep -Milliseconds 200
}

Write-Host ''
if ($seen.Count -eq 0) { Write-Host 'No CLS.ini was found, so the limit was NOT applied. This setup may not use the CLS decompressor system.' -ForegroundColor Yellow }
Write-Host 'Setup closed.'
Read-Host 'Press Enter to exit'
