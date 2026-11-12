[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$TL = [string][char]0x2554   # top-left corner
$TR = [string][char]0x2557   # top-right corner
$BL = [string][char]0x255A   # bottom-left corner
$BR = [string][char]0x255D   # bottom-right corner
$ML = [string][char]0x2560   # left T-junction
$MR = [string][char]0x2563   # right T-junction
$H  = [string][char]0x2550   # horizontal line
$V  = [string][char]0x2551   # vertical line

$W = 63   

$art = @(
    '    _    ____       ____  _____    _    ____   ____ _   _ ',
    '   / \  |  _ \     / ___|| ____|  / \  |  _ \ / ___| | | |',
    '  / _ \ | | | |    \___ \|  _|   / _ \ | |_) | |   | |_| |',
    ' / ___ \| |_| |     ___) | |___ / ___ \|  _ <| |___|  _  |',
    '/_/   \_\____/     |____/|_____/_/   \_\_| \_\\____|_| |_|'
)

$title = 'User / Computer OU Lookup Tool'
$pad   = [Math]::Floor(($W - $title.Length) / 2)

$bannerLines = @()
$bannerLines += $TL + ($H * $W) + $TR
$bannerLines += $V + (' ' * $W) + $V
foreach ($a in $art) {
    $bannerLines += $V + '  ' + $a.PadRight($W - 2) + $V
}
$bannerLines += $V + (' ' * $W) + $V
$bannerLines += $ML + ($H * $W) + $MR
$bannerLines += $V + ((' ' * $pad) + $title).PadRight($W) + $V
$bannerLines += $BL + ($H * $W) + $BR

foreach ($line in $bannerLines) {
    foreach ($char in $line.ToCharArray()) {
        Write-Host -NoNewline $char -ForegroundColor Green
        Start-Sleep -Milliseconds 1
    }
    Write-Host ""
    Start-Sleep -Milliseconds 4
}

Import-Module ActiveDirectory -ErrorAction SilentlyContinue

function Get-LevenshteinDistance {
    param(
        [string]$Source,
        [string]$Target
    )

    $sourceLength = $Source.Length
    $targetLength = $Target.Length

    if ($sourceLength -eq 0) { return $targetLength }
    if ($targetLength -eq 0) { return $sourceLength }

    $matrix = New-Object 'int[,]' ($sourceLength + 1), ($targetLength + 1)

    for ($i = 0; $i -le $sourceLength; $i++) { $matrix[$i, 0] = $i }
    for ($j = 0; $j -le $targetLength; $j++) { $matrix[0, $j] = $j }

    for ($i = 1; $i -le $sourceLength; $i++) {
        for ($j = 1; $j -le $targetLength; $j++) {
            $cost = if ($Source[$i - 1] -eq $Target[$j - 1]) { 0 } else { 1 }
            $delete = $matrix[($i - 1), $j] + 1
            $insert = $matrix[$i, ($j - 1)] + 1
            $substitute = $matrix[($i - 1), ($j - 1)] + $cost
            $matrix[$i, $j] = [Math]::Min([Math]::Min($delete, $insert), $substitute)
        }
    }

    return $matrix[$sourceLength, $targetLength]
}


function Get-LeafOU {
    param([string]$CanonicalName)

    if ([string]::IsNullOrWhiteSpace($CanonicalName)) { return "" }

    $segments = $CanonicalName -split '/'
    if ($segments.Count -lt 2) { return "" }

    $middle = $segments[0..($segments.Count - 2)]

    for ($i = 0; $i -lt $middle.Count; $i++) {
        if ($middle[$i].Trim() -match '^[A-Z]{2}$') {
            if ($i + 1 -lt $middle.Count) {
                return $middle[$i + 1].Trim()
            }
        }
    }


    return $middle[$middle.Count - 1].Trim()
}


function Test-FuzzyOUMatch {
    param(
        [string]$Canonical1,
        [string]$Canonical2
    )

    if ([string]::IsNullOrWhiteSpace($Canonical1) -or [string]::IsNullOrWhiteSpace($Canonical2)) {
        return [PSCustomObject]@{
            UserDept     = ""
            ComputerDept = ""
            PercentMatch = 0
            Status       = "N/A"
        }
    }

    $dept1 = Get-LeafOU -CanonicalName $Canonical1
    $dept2 = Get-LeafOU -CanonicalName $Canonical2

    $d1 = $dept1.ToLower()
    $d2 = $dept2.ToLower()

    if ($d1 -eq $d2) {
        $percent = 100
    }
    else {
        $distance = Get-LevenshteinDistance -Source $d1 -Target $d2
        $maxLen = [Math]::Max($d1.Length, $d2.Length)
        $percent = if ($maxLen -gt 0) { [Math]::Round((1 - ($distance / $maxLen)) * 100, 1) } else { 0 }
        if ($percent -lt 0) { $percent = 0 }
    }

    $status = switch ($percent) {
        { $_ -eq 100 } { "Exact Location Match"; break }
        { $_ -ge 80 }  { "Likely Same Location"; break }
        { $_ -ge 50 }  { "Possibly Related Location"; break }
        { $_ -ge 1 }   { "Weak Match"; break }
        default        { "No Match" }
    }

    return [PSCustomObject]@{
        UserDept     = $dept1
        ComputerDept = $dept2
        PercentMatch = $percent
        Status       = $status
    }
}

while ($true) {
    $username = Read-Host "Enter the username to look up"
    $computerName = Read-Host "Enter the computer name to look up"

    try {
        $userCanonical = (Get-ADUser -Identity $username -Properties CanonicalName -ErrorAction Stop).CanonicalName
        $userError = $null
    }
    catch {
        $userCanonical = $null
        $userError = $_.Exception.Message
    }

    try {
        $computerCanonical = (Get-ADComputer -Identity $computerName -Properties CanonicalName -ErrorAction Stop).CanonicalName
        $computerError = $null
    }
    catch {
        $computerCanonical = $null
        $computerError = $_.Exception.Message
    }

    Write-Host ""
    Write-Host "RESULTS" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "-- User: $username --" -ForegroundColor Yellow
    if ($userError) {
        Write-Warning "Search result not found for user '$username': $userError"
        Write-Host "  Example valid usernames (SamAccountName format): jdoe, msmith" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "Canonical Name : $userCanonical"
    }

    Write-Host ""
    Write-Host "-- Computer: $computerName --" -ForegroundColor Yellow
    if ($computerError) {
        Write-Warning "Search result not found for computer '$computerName': $computerError"
        Write-Host "  Example valid computer names (hostname format): WP49993LT, WP46224DT" -ForegroundColor DarkYellow
    }
    else {
        Write-Host "Canonical Name : $computerCanonical"
    }

    Write-Host ""
    Write-Host "-- Location Comparison --" -ForegroundColor Yellow
    if ($userError -or $computerError) {
        Write-Host "  Skipped - one or both lookups failed above." -ForegroundColor DarkGray
    }
    else {
        $ouMatch = Test-FuzzyOUMatch -Canonical1 $userCanonical -Canonical2 $computerCanonical
        $color = switch ($ouMatch.Status) {
            "Exact Location Match"      { "Green" }
            "Likely Same Location"      { "Green" }
            "Possibly Related Location" { "Yellow" }
            "Weak Match"                { "Red" }
            default                     { "Red" }
        }
        Write-Host "  User Location     : $($ouMatch.UserDept)"
        Write-Host "  Computer Location : $($ouMatch.ComputerDept)"
        Write-Host "  Match Score       : $($ouMatch.PercentMatch)%" -ForegroundColor $color
        Write-Host "  Result            : $($ouMatch.Status)" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host ""
}
