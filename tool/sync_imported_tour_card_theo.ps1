$ErrorActionPreference = 'Stop'

function Decode-HtmlText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return $Text.Replace('&amp;', '&').Replace('&#039;', "'").Replace('&quot;', '"').Replace('&nbsp;', ' ').Trim()
}

$headers = @{
    'User-Agent' = 'Mozilla/5.0 (compatible; CodexTourCardSync/1.0)'
}

$listUrl = 'https://www.dartsdatabase.co.uk/tour_card_holders.php'
$listHtml = (Invoke-WebRequest -Uri $listUrl -Headers $headers -UseBasicParsing).Content

$playerRegex = [regex]"player-profile-live\.php\?pid=(\d+)['""][^>]*>([^<]+)</a>"
$tourCardPlayers = [System.Collections.Generic.List[object]]::new()
$seenPids = [System.Collections.Generic.HashSet[string]]::new()

foreach ($match in $playerRegex.Matches($listHtml)) {
    $playerPid = $match.Groups[1].Value
    $name = Decode-HtmlText $match.Groups[2].Value
    if ($seenPids.Add($playerPid)) {
        $tourCardPlayers.Add([pscustomobject]@{
            pid = $playerPid
            name = $name
        })
    }
}

if ($tourCardPlayers.Count -ne 128) {
    throw "Expected 128 tour card holders, found $($tourCardPlayers.Count)."
}

$appData = $env:APPDATA
if ([string]::IsNullOrWhiteSpace($appData)) {
    throw 'APPDATA is not available.'
}

$dataDir = Join-Path $appData 'DartFlutterApp'
$dbPath = Join-Path $dataDir 'computer_players.json'
if (-not (Test-Path $dbPath)) {
    throw "Database file not found: $dbPath"
}

$raw = Get-Content -Raw -Path $dbPath
$payload = $raw | ConvertFrom-Json

$players = @($payload.players)
$importedPlayers = @($players | Where-Object { $_.source -eq 'imported' })
if ($importedPlayers.Count -ne 128) {
    throw "Expected 128 imported players in local database, found $($importedPlayers.Count)."
}

$playersById = @{}
foreach ($player in $players) {
    if ($null -ne $player.id) {
        $playersById[$player.id] = $player
    }
}

$timestamp = Get-Date
$updatedCount = 0

for ($index = 0; $index -lt $tourCardPlayers.Count; $index++) {
    $tourCardPlayer = $tourCardPlayers[$index]
    $profileUrl = "https://www.dartsdatabase.co.uk/player-profile-live.php?pid=$($tourCardPlayer.pid)"
    $profileHtml = (Invoke-WebRequest -Uri $profileUrl -Headers $headers -UseBasicParsing).Content

    $currentStatsStart = $profileHtml.IndexOf('Current Years Statistics')
    $currentStatsEnd = $profileHtml.IndexOf('This Years Results', $currentStatsStart)
    if ($currentStatsStart -lt 0 -or $currentStatsEnd -lt 0) {
        throw "Could not find 2026 stats for $($tourCardPlayer.name) ($($tourCardPlayer.pid))."
    }

    $currentStats = $profileHtml.Substring($currentStatsStart, $currentStatsEnd - $currentStatsStart)
    $averageRegex = [regex]::new(
        'Average.*?([0-9]+\.[0-9]+)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $averageMatch = $averageRegex.Match($currentStats)
    if (-not $averageMatch.Success) {
        throw "Could not parse average for $($tourCardPlayer.name) ($($tourCardPlayer.pid))."
    }

    $average = [double]::Parse($averageMatch.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture)
    $id = "db-player-$($tourCardPlayer.pid)"
    $player = $playersById[$id]
    if ($null -eq $player) {
        throw "Imported player not found in local database: $id"
    }

    $player.theoreticalAverage = [math]::Round($average, 2)
    $player.updatedAt = $timestamp.ToString('o')
    $player.lastModifiedReason = 'tour_card_average_sync'
    $updatedCount += 1

    Write-Host ("[{0}/128] {1} -> {2:N2}" -f ($index + 1), $tourCardPlayer.name, $average)
}

$backupPath = Join-Path $dataDir ("computer_players.backup.{0}.json" -f [DateTimeOffset]::Now.ToUnixTimeMilliseconds())
Set-Content -Path $backupPath -Value $raw -Encoding UTF8

$json = $payload | ConvertTo-Json -Depth 100
Set-Content -Path $dbPath -Value $json -Encoding UTF8

Write-Host "Updated $updatedCount imported players."
Write-Host "Backup created: $backupPath"
Write-Host "Database updated: $dbPath"
