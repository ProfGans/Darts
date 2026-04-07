$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-AgeFromBirthDate {
  param(
    [Parameter(Mandatory = $true)]
    [datetime]$BirthDate
  )

  $today = Get-Date
  $years = $today.Year - $BirthDate.Year
  if ($today.Month -lt $BirthDate.Month -or ($today.Month -eq $BirthDate.Month -and $today.Day -lt $BirthDate.Day)) {
    $years--
  }
  if ($years -lt 0) {
    return $null
  }
  return $years
}

function Get-DateOfBirthFromProfile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PlayerId
  )

  $uri = "https://www.dartsdatabase.co.uk/player-profile-live.php?pid=$PlayerId"
  $html = (Invoke-WebRequest -Uri $uri -UseBasicParsing).Content
  $match = [regex]::Match($html, 'Date of Birth\s*</[^>]+>\s*<[^>]+>\s*([0-9]{2}/[0-9]{2}/[0-9]{4})')
  if (-not $match.Success) {
    return $null
  }

  return [datetime]::ParseExact(
    $match.Groups[1].Value,
    'dd/MM/yyyy',
    [System.Globalization.CultureInfo]::InvariantCulture
  )
}

function Get-DateOfBirthFromWikipediaSearch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $query = [uri]::EscapeDataString("$Name darts")
  $uri = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$query&format=json"
  $json = (Invoke-WebRequest -Uri $uri -UseBasicParsing).Content | ConvertFrom-Json
  if ($null -eq $json.query -or $null -eq $json.query.search -or $json.query.search.Count -eq 0) {
    return $null
  }

  $snippet = [string]$json.query.search[0].snippet
  $plainSnippet = ($snippet -replace '<[^>]+>', '')
  $match = [regex]::Match($plainSnippet, 'born\s+([0-9]{1,2}\s+[A-Za-z]+\s+[0-9]{4})')
  if (-not $match.Success) {
    return $null
  }

  return [datetime]::ParseExact(
    $match.Groups[1].Value,
    'd MMMM yyyy',
    [System.Globalization.CultureInfo]::InvariantCulture
  )
}

function Get-DateOfBirthFromGermanWikipediaSearch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $query = [uri]::EscapeDataString("$Name Dart")
  $uri = "https://de.wikipedia.org/w/api.php?action=query&list=search&srsearch=$query&format=json"
  $json = (Invoke-WebRequest -Uri $uri -UseBasicParsing).Content | ConvertFrom-Json
  if ($null -eq $json.query -or $null -eq $json.query.search -or $json.query.search.Count -eq 0) {
    return $null
  }

  $snippet = [string]$json.query.search[0].snippet
  $plainSnippet = ($snippet -replace '<[^>]+>', '')
  $match = [regex]::Match($plainSnippet, '([0-9]{1,2})\.\s+([A-Za-zÄÖÜäöüß]+)\s+([0-9]{4})')
  if (-not $match.Success) {
    return $null
  }

  return [datetime]::ParseExact(
    "$($match.Groups[1].Value). $($match.Groups[2].Value) $($match.Groups[3].Value)",
    'd. MMMM yyyy',
    [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
  )
}

$path = Join-Path $env:APPDATA 'DartFlutterApp\computer_players.json'
if (-not (Test-Path $path)) {
  throw "Datei nicht gefunden: $path"
}

$raw = Get-Content -Path $path -Raw
$json = $raw | ConvertFrom-Json
if ($null -eq $json.players) {
  throw 'Keine Spielerliste in computer_players.json gefunden.'
}

$manualOverrides = @{
  'Dominik Gruellich' = [datetime]'2002-03-27'
  'David Sharp' = [datetime]'1989-03-23'
  'Thomas Lovely' = [datetime]'1996-06-28'
  'Sietse Lap' = [datetime]'1988-07-12'
  'Samuel Price' = [datetime]'1993-03-20'
  'Maximilian Czerwinski' = [datetime]'1998-06-22'
  'Tavis Dudeney' = [datetime]'2004-03-08'
  'Tyler Thorpe' = [datetime]'2002-10-24'
  'Marvin Kraft' = [datetime]'2000-05-06'
  'Matthias Ehlers' = [datetime]'1981-03-25'
  'Pascal Rupprecht' = [datetime]'2000-04-25'
  'Adam Warner' = [datetime]'1997-05-05'
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $env:APPDATA "DartFlutterApp\computer_players.birthdate_backup_$timestamp.json"
Set-Content -Path $backupPath -Value $raw

$updated = 0
$missing = New-Object System.Collections.Generic.List[string]

foreach ($player in $json.players) {
  if ($player.source -ne 'imported') {
    continue
  }
  if (-not ($player.id -match '^db-player-(\d+)$')) {
    $missing.Add("$($player.name) (ungueltige id)")
    continue
  }

  $playerId = $Matches[1]
  try {
    $birthDate = $manualOverrides[$player.name]
    if ($null -eq $birthDate) {
      $birthDate = Get-DateOfBirthFromProfile -PlayerId $playerId
    }
    if ($null -eq $birthDate) {
      $birthDate = Get-DateOfBirthFromWikipediaSearch -Name $player.name
    }
    if ($null -eq $birthDate) {
      $birthDate = Get-DateOfBirthFromGermanWikipediaSearch -Name $player.name
    }
    if ($null -eq $birthDate) {
      $missing.Add($player.name)
      continue
    }

    $player.birthDate = $birthDate.ToString('o')
    $player.age = Get-AgeFromBirthDate -BirthDate $birthDate
    $updated++
    Write-Output "OK: $($player.name) -> $($birthDate.ToString('yyyy-MM-dd'))"
  } catch {
    $missing.Add("$($player.name) (Fehler)")
    Write-Output "ERR: $($player.name) -> $($_.Exception.Message)"
  }
}

$json | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $path

$workspaceAsset = 'C:\Users\johan\Desktop\Dart\flutter_app\assets\data\default_computer_players.json'
if (Test-Path $workspaceAsset) {
  $assetJson = Get-Content -Path $workspaceAsset -Raw | ConvertFrom-Json
  $assetIndex = @{}
  foreach ($assetPlayer in $assetJson.players) {
    $assetIndex[$assetPlayer.id] = $assetPlayer
  }
  foreach ($player in $json.players) {
    if ($assetIndex.ContainsKey($player.id)) {
      $assetPlayer = $assetIndex[$player.id]
      if ($assetPlayer.PSObject.Properties['birthDate']) {
        $assetPlayer.birthDate = $player.birthDate
      } else {
        $assetPlayer | Add-Member -NotePropertyName 'birthDate' -NotePropertyValue $player.birthDate
      }
      if ($assetPlayer.PSObject.Properties['age']) {
        $assetPlayer.age = $player.age
      } else {
        $assetPlayer | Add-Member -NotePropertyName 'age' -NotePropertyValue $player.age
      }
    }
  }
  $assetJson | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $workspaceAsset
}

Write-Output "UPDATED=$updated"
Write-Output "BACKUP=$backupPath"
if ($missing.Count -gt 0) {
  Write-Output "MISSING=$($missing.Count)"
  $missing | ForEach-Object { Write-Output "MISSING_PLAYER=$_"}
}
