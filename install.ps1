# AICS Pro Plugin installer for Windows.
#
#   irm https://github.com/djkim-wbd/after-effects-aics-plugin-dist/releases/latest/download/install.ps1 | iex
#
# Downloads the plugin, checks its SHA-256, copies it into After Effects, and
# turns on the CEP setting the panel needs. Close After Effects first.

$ErrorActionPreference = "Stop"

$BaseUrl = if ($env:AICS_BASE_URL) { $env:AICS_BASE_URL.TrimEnd("/") } else {
  "https://github.com/djkim-wbd/after-effects-aics-plugin-dist/releases/latest/download"
}
$ZipName = "AICS-Pro-Plugin.zip"
$Bundle = "com.aicspro.aftereffects"
$Dest = Join-Path $env:APPDATA "Adobe\CEP\extensions\$Bundle"

Write-Host ""
Write-Host "  AICS Pro Plugin — After Effects"
Write-Host ""

$Work = Join-Path $env:TEMP ("aics-pro-plugin-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Work | Out-Null
try {
  Write-Host "  Downloading…"
  Invoke-WebRequest -UseBasicParsing "$BaseUrl/checksums.txt" -OutFile (Join-Path $Work "checksums.txt")
  Invoke-WebRequest -UseBasicParsing "$BaseUrl/$ZipName" -OutFile (Join-Path $Work $ZipName)

  $expected = (Get-Content (Join-Path $Work "checksums.txt") | Where-Object { $_ -match "\s$([regex]::Escape($ZipName))\s*$" } | ForEach-Object { ($_ -split "\s+")[0] } | Select-Object -First 1)
  if (-not $expected) { throw "checksums.txt has no line for $ZipName." }
  $got = (Get-FileHash -Algorithm SHA256 (Join-Path $Work $ZipName)).Hash.ToLower()
  if ($got -ne $expected.ToLower()) {
    throw "The download did not match the published checksum.`n  Got      $got`n  Expected $expected"
  }
  Write-Host "  Download verified"

  $unpacked = Join-Path $Work "unpacked"
  Expand-Archive -LiteralPath (Join-Path $Work $ZipName) -DestinationPath $unpacked -Force
  $zxp = Get-ChildItem -Path $unpacked -Filter "$Bundle-*.zxp" -Recurse | Sort-Object Name | Select-Object -Last 1
  if (-not $zxp) { throw "The zip did not contain $Bundle-*.zxp." }

  if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
  New-Item -ItemType Directory -Path $Dest -Force | Out-Null
  $tmpZip = Join-Path $env:TEMP "$Bundle.zip"
  Copy-Item -Force $zxp.FullName $tmpZip
  Expand-Archive -LiteralPath $tmpZip -DestinationPath $Dest -Force
  Remove-Item -Force $tmpZip

  foreach ($version in 9, 10, 11, 12, 13) {
    New-Item -Path "HKCU:\Software\Adobe\CSXS.$version" -Force | Out-Null
    New-ItemProperty -Path "HKCU:\Software\Adobe\CSXS.$version" -Name PlayerDebugMode -Value "1" -PropertyType String -Force | Out-Null
  }

  Write-Host "  Installed to $Dest"
  Write-Host ""
  Write-Host "  Next:"
  Write-Host "    1. Open After Effects (quit it first if it was already running)."
  Write-Host "    2. Edit → Preferences → Scripting & Expressions → tick"
  Write-Host "       `"Allow Scripts to Write Files and Access Network`"."
  Write-Host "    3. Window → Extensions → AICS Pro Plugin."
  Write-Host "    4. In the panel's Settings, paste your tool key and click Connect."
  Write-Host ""
}
finally {
  Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
