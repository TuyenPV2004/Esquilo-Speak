$ErrorActionPreference = 'Stop'

$packageRoot = Join-Path $PSScriptRoot '..\courses\course-en-for-vi\course-a1-v3'
$scriptsPath = Join-Path $packageRoot 'media-scripts.json'
$mediaRoot = Join-Path $packageRoot 'media'
if (-not (Test-Path -LiteralPath $scriptsPath)) {
  throw 'Run node content/tools/generate-course-a1.mjs --scripts first.'
}
New-Item -ItemType Directory -Path $mediaRoot -Force | Out-Null
$clips = Get-Content -LiteralPath $scriptsPath -Raw | ConvertFrom-Json

$voice = New-Object -ComObject SAPI.SpVoice
$selectedVoice = $voice.GetVoices() | Where-Object {
  $_.GetDescription() -eq 'Microsoft Zira Desktop - English (United States)'
} | Select-Object -First 1
if ($null -eq $selectedVoice) {
  throw 'Required English TTS voice Microsoft Zira Desktop is not installed.'
}
$voice.Voice = $selectedVoice
$voice.Rate = -1

foreach ($property in $clips.PSObject.Properties) {
  $target = Join-Path $mediaRoot ($property.Name + '.wav')
  $stream = New-Object -ComObject SAPI.SpFileStream
  $format = New-Object -ComObject SAPI.SpAudioFormat
  $format.Type = 22
  $stream.Format = $format
  $stream.Open($target, 3, $false)
  $voice.AudioOutputStream = $stream
  [void]$voice.Speak([string]$property.Value)
  $stream.Close()
}

$clipCount = @($clips.PSObject.Properties).Count
Write-Output "Generated $clipCount A1 WAV files with Microsoft Zira Desktop."
