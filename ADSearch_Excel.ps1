$ExcelPathPattern = Join-Path -Path $PSScriptRoot -ChildPath "*.xlsx"
$FullNameHeader   = "Last Login"
$HostnameHeader   = "Hostname"
$ADNameHeader     = "AD_Name"
$PercentHeader    = "OU Match Percentage"
$ReasonHeader     = "OU Match Reason"
$DomainSuffix     = ".Contoso.com"

Install-Module -Name ImportExcel -Scope CurrentUser -Force
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
Import-Module ImportExcel -ErrorAction Stop

$matchedFiles = @(Get-ChildItem -Path $ExcelPathPattern -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '~$*' })

if ($matchedFiles.Count -eq 0) {
    throw "No .xlsx file found matching pattern '$ExcelPathPattern'."
}
elseif ($matchedFiles.Count -gt 1) {
    $names = ($matchedFiles | Select-Object -ExpandProperty Name) -join ", "
    throw "Multiple .xlsx files matched pattern '$ExcelPathPattern': $names. Narrow the pattern or set an explicit path."
}

$ExcelPath = $matchedFiles[0].FullName

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

function Get-NormalizedName {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $normalized = $Text -replace '[\u00A0\u200B\s]+', ' '
    return $normalized.Trim()
}

function Get-ShortHostname {
    param(
        [string]$Hostname,
        [string]$Suffix
    )
    if ([string]::IsNullOrWhiteSpace($Hostname)) { return "" }

    $trimmed = $Hostname.Trim()

    if ($trimmed.ToLower().EndsWith($Suffix.ToLower())) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - $Suffix.Length)
    }

    return $trimmed.Trim()
}

function Resolve-SamAccountName {
    param([string]$FullName)

    if ([string]::IsNullOrWhiteSpace($FullName)) {
        return [PSCustomObject]@{ SamAccountName = $null; ShortCode = "Blank"; FullError = "Input name was blank." }
    }

    $FullName = Get-NormalizedName -Text $FullName
    $triedMethods = @()

    try {
        $matches = @(Get-ADUser -Filter { Name -eq $FullName } -Properties SamAccountName, Enabled -ErrorAction Stop)
        $triedMethods += "Name"

        if ($matches.Count -eq 0) {
            $matches = @(Get-ADUser -Filter { DisplayName -eq $FullName } -Properties SamAccountName, Enabled -ErrorAction Stop)
            $triedMethods += "DisplayName"
        }

        if ($matches.Count -eq 0) {
            $parts = $FullName -split '\s+' | Where-Object { $_ }
            if ($parts.Count -ge 2) {
                $firstToken = $parts[0]
                $lastToken  = $parts[$parts.Count - 1]
                $matches = @(Get-ADUser -Filter { GivenName -eq $firstToken -and Surname -eq $lastToken } -Properties SamAccountName, Enabled -ErrorAction Stop)
                $triedMethods += "GivenName+Surname ('$firstToken' / '$lastToken')"
            }
        }

        if ($matches.Count -eq 0) {
            $escapedName = $FullName -replace '([\\\*\(\)])', '\$1'
            $matches = @(Get-ADUser -LDAPFilter "(anr=$escapedName)" -Properties SamAccountName, Enabled -ErrorAction Stop)
            $triedMethods += "ANR fuzzy search"
        }

        if ($matches.Count -eq 0) {
            $methodsText = $triedMethods -join ", "
            return [PSCustomObject]@{
                SamAccountName = $null
                ShortCode      = "No Match"
                FullError      = "No AD match found for '$FullName' (tried: $methodsText)."
            }
        }
        elseif ($matches.Count -eq 1) {
            if ($matches[0].Enabled) {
                return [PSCustomObject]@{ SamAccountName = $matches[0].SamAccountName; ShortCode = $null; FullError = $null }
            }
            else {
                return [PSCustomObject]@{
                    SamAccountName = $null
                    ShortCode      = "Disabled"
                    FullError      = "Matched account '$($matches[0].SamAccountName)' for '$FullName' is disabled."
                }
            }
        }
        else {
            $enabledMatches  = @($matches | Where-Object { $_.Enabled })
            $disabledMatches = @($matches | Where-Object { -not $_.Enabled })

            if ($enabledMatches.Count -eq 1) {
                return [PSCustomObject]@{ SamAccountName = $enabledMatches[0].SamAccountName; ShortCode = $null; FullError = $null }
            }
            elseif ($enabledMatches.Count -eq 0) {
                $disabledNames = ($disabledMatches | Select-Object -ExpandProperty SamAccountName) -join ", "
                return [PSCustomObject]@{
                    SamAccountName = $null
                    ShortCode      = "Disabled"
                    FullError      = "All matches for '$FullName' are disabled: $disabledNames."
                }
            }
            else {
                $names = ($enabledMatches | Select-Object -ExpandProperty SamAccountName) -join ", "
                return [PSCustomObject]@{
                    SamAccountName = $null
                    ShortCode      = "Ambiguous"
                    FullError      = "Multiple enabled matches for '$FullName': $names."
                }
            }
        }
    }
    catch {
        return [PSCustomObject]@{
            SamAccountName = $null
            ShortCode      = "Lookup Failed"
            FullError      = "Exception while resolving '$FullName': $($_.Exception.Message)"
        }
    }
}

function Get-ColumnIndexByHeader {
    param(
        $Worksheet,
        [string]$HeaderText,
        [int]$LastColumn
    )
    for ($col = 1; $col -le $LastColumn; $col++) {
        $cellText = $Worksheet.Cells[1, $col].Text
        if (-not [string]::IsNullOrWhiteSpace($cellText) -and ($cellText.Trim() -ieq $HeaderText.Trim())) {
            return $col
        }
    }
    return -1
}

$pkg = Open-ExcelPackage -Path $ExcelPath

$qualifyingSheets = @()
$sheetsChecked    = @()

foreach ($candidate in $pkg.Workbook.Worksheets) {
    if (-not $candidate.Dimension) { continue }

    $candidateLastCol = $candidate.Dimension.End.Column
    $tryFullNameCol = Get-ColumnIndexByHeader -Worksheet $candidate -HeaderText $FullNameHeader -LastColumn $candidateLastCol
    $tryHostCol     = Get-ColumnIndexByHeader -Worksheet $candidate -HeaderText $HostnameHeader -LastColumn $candidateLastCol

    $headerSummary = @()
    for ($col = 1; $col -le $candidateLastCol; $col++) {
        $headerSummary += "[$col] '$($candidate.Cells[1, $col].Text)'"
    }
    $sheetsChecked += "'$($candidate.Name)': $($headerSummary -join ', ')"

    if ($tryFullNameCol -ne -1 -and $tryHostCol -ne -1) {
        $qualifyingSheets += [PSCustomObject]@{
            Worksheet    = $candidate
            FullNameCol  = $tryFullNameCol
            HostCol      = $tryHostCol
        }
    }
}

if ($qualifyingSheets.Count -eq 0) {
    Close-ExcelPackage $pkg -NoSave
    $summaryText = $sheetsChecked -join "`n"
    throw "No worksheet containing both '$FullNameHeader' and '$HostnameHeader' columns was found. Headers found per sheet:`n$summaryText"
}

Write-Warning "Found $($qualifyingSheets.Count) worksheet(s) with both required columns: $(($qualifyingSheets.Worksheet.Name) -join ', '). Sheets without both columns will be skipped."

$errorLog = @()

foreach ($sheetInfo in $qualifyingSheets) {

    $ws          = $sheetInfo.Worksheet
    $fullNameCol = $sheetInfo.FullNameCol
    $hostCol     = $sheetInfo.HostCol

    Write-Warning "Processing worksheet '$($ws.Name)' - '$FullNameHeader' in column $fullNameCol, '$HostnameHeader' in column $hostCol."

    $lastRow = $ws.Dimension.End.Row
    $lastCol = $ws.Dimension.End.Column

    # Reuse existing result columns on repeat runs instead of stacking duplicates.
    $adNameCol = Get-ColumnIndexByHeader -Worksheet $ws -HeaderText $ADNameHeader -LastColumn $lastCol
    $percentCol = Get-ColumnIndexByHeader -Worksheet $ws -HeaderText $PercentHeader -LastColumn $lastCol
    $reasonCol = Get-ColumnIndexByHeader -Worksheet $ws -HeaderText $ReasonHeader -LastColumn $lastCol

    $nextColumn = $lastCol + 1

    if ($adNameCol -eq -1)  { $adNameCol  = $nextColumn; $nextColumn++ }
    if ($percentCol -eq -1) { $percentCol = $nextColumn; $nextColumn++ }
    if ($reasonCol -eq -1)  { $reasonCol  = $nextColumn; $nextColumn++ }

    $ws.Cells[1, $adNameCol].Value = $ADNameHeader
    $ws.Cells[1, $adNameCol].Style.Font.Bold = $true

    $ws.Cells[1, $percentCol].Value = $PercentHeader
    $ws.Cells[1, $percentCol].Style.Font.Bold = $true

    $ws.Cells[1, $reasonCol].Value = $ReasonHeader
    $ws.Cells[1, $reasonCol].Style.Font.Bold = $true

    for ($row = 2; $row -le $lastRow; $row++) {

        $fullName = $ws.Cells[$row, $fullNameCol].Text.Trim()

        $ws.Cells[$row, $adNameCol].Value = $null
        $ws.Cells[$row, $percentCol].Value = $null
        $ws.Cells[$row, $reasonCol].Value = $null

        if ([string]::IsNullOrWhiteSpace($fullName)) {
            $ws.Cells[$row, $reasonCol].Value = "Skipped - no Last Login value"
            continue
        }

        $resolved = Resolve-SamAccountName -FullName $fullName

        if ($resolved.SamAccountName) {
            $ws.Cells[$row, $adNameCol].Value = $resolved.SamAccountName
        }
        else {
            $ws.Cells[$row, $adNameCol].Value = "ERROR: $($resolved.ShortCode)"
            $ws.Cells[$row, $reasonCol].Value = "Skipped - $($resolved.ShortCode)"

            $errorLog += [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Worksheet = $ws.Name
                Row       = $row
                Field     = $ADNameHeader
                Input     = $fullName
                ShortCode = $resolved.ShortCode
                FullError = $resolved.FullError
            }
        }
    }

    for ($row = 2; $row -le $lastRow; $row++) {

        $username        = $ws.Cells[$row, $adNameCol].Text.Trim()
        $computerNameRaw = $ws.Cells[$row, $hostCol].Text.Trim()
        $computerName    = Get-ShortHostname -Hostname $computerNameRaw -Suffix $DomainSuffix

        if ([string]::IsNullOrWhiteSpace($username)) {
            $ws.Cells[$row, $percentCol].Value = $null
            $ws.Cells[$row, $reasonCol].Value = "Skipped - no valid AD_Name"
            continue
        }

        if ($username.StartsWith("ERROR:", [System.StringComparison]::OrdinalIgnoreCase)) {
            $ws.Cells[$row, $percentCol].Value = $null

            $existingReason = $ws.Cells[$row, $reasonCol].Text

            if ([string]::IsNullOrWhiteSpace($existingReason)) {
                $ws.Cells[$row, $reasonCol].Value = "Skipped - no valid AD_Name"
            }

            continue
        }

        if ([string]::IsNullOrWhiteSpace($computerName)) {
            $ws.Cells[$row, $percentCol].Value = $null
            $ws.Cells[$row, $reasonCol].Value = "Skipped - no Hostname"
            continue
        }

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

        if ($userError) {
            $ws.Cells[$row, $percentCol].Value = $null
            $ws.Cells[$row, $reasonCol].Value = "ERROR: User Lookup"

            $errorLog += [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Worksheet = $ws.Name
                Row       = $row
                Field     = $ReasonHeader
                Input     = $username
                ShortCode = "User Lookup"
                FullError = "User lookup failed for '$username': $userError"
            }

            continue
        }

        if ($computerError) {
            $ws.Cells[$row, $percentCol].Value = $null
            $ws.Cells[$row, $reasonCol].Value = "ERROR: Computer Lookup"

            $errorLog += [PSCustomObject]@{
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Worksheet = $ws.Name
                Row       = $row
                Field     = $ReasonHeader
                Input     = $computerName
                ShortCode = "Computer Lookup"
                FullError = "Computer lookup failed for '$computerName' (raw value: '$computerNameRaw'): $computerError"
            }

            continue
        }

        $ouMatch = Test-FuzzyOUMatch -Canonical1 $userCanonical -Canonical2 $computerCanonical

        # Store as a true numeric percentage (0.857 displays as 85.7%).
        $ws.Cells[$row, $percentCol].Value = $ouMatch.PercentMatch / 100
        $ws.Cells[$row, $percentCol].Style.Numberformat.Format = "0.0%"

        $ws.Cells[$row, $reasonCol].Value = "$($ouMatch.Status) | User location: $($ouMatch.UserDept) | Computer location: $($ouMatch.ComputerDept)"
    }

    $ws.Column($adNameCol).AutoFit()
    $ws.Column($percentCol).AutoFit()
    $ws.Column($reasonCol).AutoFit()

    if ($ws.Column($reasonCol).Width -gt 75) {
        $ws.Column($reasonCol).Width = 75
        $ws.Column($reasonCol).Style.WrapText = $true
    }
}

$logSheetName = "ADSearch_ErrorLog"
if ($pkg.Workbook.Worksheets[$logSheetName]) {
    $pkg.Workbook.Worksheets.Delete($logSheetName)
}
$logWs = $pkg.Workbook.Worksheets.Add($logSheetName)

$logHeaders = @("Timestamp", "Worksheet", "Row", "Field", "Input", "ShortCode", "FullError")
for ($col = 1; $col -le $logHeaders.Count; $col++) {
    $logWs.Cells[1, $col].Value = $logHeaders[$col - 1]
    $logWs.Cells[1, $col].Style.Font.Bold = $true
}

$logRow = 2
foreach ($entry in $errorLog) {
    $logWs.Cells[$logRow, 1].Value = $entry.Timestamp
    $logWs.Cells[$logRow, 2].Value = $entry.Worksheet
    $logWs.Cells[$logRow, 3].Value = $entry.Row
    $logWs.Cells[$logRow, 4].Value = $entry.Field
    $logWs.Cells[$logRow, 5].Value = $entry.Input
    $logWs.Cells[$logRow, 6].Value = $entry.ShortCode
    $logWs.Cells[$logRow, 7].Value = $entry.FullError
    $logRow++
}

if ($errorLog.Count -gt 0) {
    for ($col = 1; $col -le $logHeaders.Count; $col++) {
        $logWs.Column($col).AutoFit()
    }
}

Write-Warning "Logged $($errorLog.Count) error(s) to worksheet '$logSheetName'."

Close-ExcelPackage $pkg
