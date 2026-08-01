$ErrorActionPreference = 'Stop'

$packageRoot = Join-Path $PSScriptRoot '..\courses\course-en-for-vi\unit-1-v2'
$mediaRoot = Join-Path $packageRoot 'media'
New-Item -ItemType Directory -Path $mediaRoot -Force | Out-Null

$clips = [ordered]@{
  'media-greetings-listen' = 'Hello'
  'media-greetings-dictation' = 'Hello'
  'media-name-listen' = 'name'
  'media-name-dictation' = 'My name is Ana'
  'media-feelings-listen' = 'fine'
  'media-feelings-dictation' = 'How are you?'
  'media-age-listen' = 'twelve'
  'media-age-dictation' = 'I am ten'
  'media-checkpoint-listen' = 'introduce'
  'media-checkpoint-dictation' = 'Hello, my name is Sam'
}

$voice = New-Object -ComObject SAPI.SpVoice
$selectedVoice = $voice.GetVoices() | Where-Object {
  $_.GetDescription() -eq 'Microsoft Zira Desktop - English (United States)'
} | Select-Object -First 1
if ($null -eq $selectedVoice) {
  throw 'Required English TTS voice Microsoft Zira Desktop is not installed.'
}
$voice.Voice = $selectedVoice
$voice.Rate = -1

foreach ($clip in $clips.GetEnumerator()) {
  $target = Join-Path $mediaRoot ($clip.Key + '.wav')
  $stream = New-Object -ComObject SAPI.SpFileStream
  $format = New-Object -ComObject SAPI.SpAudioFormat
  $format.Type = 22
  $stream.Format = $format
  $stream.Open($target, 3, $false)
  $voice.AudioOutputStream = $stream
  [void]$voice.Speak($clip.Value)
  $stream.Close()
}

Write-Output "Generated $($clips.Count) Unit 1 WAV files with Microsoft Zira Desktop."
