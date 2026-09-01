<#
.SYNOPSIS
Counts identities created from the start of the current year through an as-of timestamp.

.DESCRIPTION
Uses the SailPoint PowerShell SDK search APIs to query the identities index for records
whose created timestamp is in the current calendar year and outputs the total count.
The query targets correlated identities to represent onboarded users.

.PARAMETER AsOf
Upper bound timestamp for the calculation. Unspecified DateTime values are treated as UTC.

.PARAMETER PageSize
Number of search results requested per page.

.PARAMETER MaxResults
Maximum number of identities to retrieve while counting. If the dataset exceeds this value,
the count is capped and a warning is emitted. Maximum allowed value is
[int]::MaxValue - 1 (2147483646) so the script can safely request one additional
record to detect truncation.
#>
[CmdletBinding()]
param(
    [datetime]$AsOf = (Get-Date).ToUniversalTime(),
    [ValidateRange(1, [int]::MaxValue)]
    [int]$PageSize = 250,
    [ValidateRange(1, 2147483646)]
    [int]$MaxResults = 200000
)

$requiredCommands = @(
    'ConvertFrom-JsonToSearch',
    'Invoke-PaginateSearch'
)

foreach ($command in $requiredCommands) {
    if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
        throw "Missing required cmdlet '$command'. Install/import the SailPoint PowerShell SDK before running this script."
    }
}

$asOfUtc = switch ($AsOf.Kind) {
    ([System.DateTimeKind]::Utc) { $AsOf }
    ([System.DateTimeKind]::Local) { $AsOf.ToUniversalTime() }
    default { [System.DateTime]::SpecifyKind($AsOf, [System.DateTimeKind]::Utc) }
}
$startOfYearUtc = [datetime]::new($asOfUtc.Year, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)

$searchJson = @"
{
  "indices": ["identities"],
  "query": {
    "query": "correlated:true"
  },
  "sort": ["id"],
  "filters": {
    "created": {
      "type": "RANGE",
      "range": {
        "lower": {
          "value": "$($startOfYearUtc.ToString('o'))",
          "inclusive": true
        },
        "upper": {
          "value": "$($asOfUtc.ToString('o'))",
          "inclusive": true
        }
      }
    }
  }
}
"@

$search = ConvertFrom-JsonToSearch -Json $searchJson
$queryLimit = $MaxResults + 1
$results = Invoke-PaginateSearch -Search $search -Increment $PageSize -Limit $queryLimit

$retrievedCount = @($results).Count
$newUserCount = [Math]::Min($retrievedCount, $MaxResults)

if ($retrievedCount -gt $MaxResults) {
    Write-Warning "Returned count exceeded MaxResults=$MaxResults. Increase MaxResults to retrieve an exact count."
}

[pscustomobject]@{
    Year                  = $asOfUtc.Year
    StartOfYearUtc        = $startOfYearUtc.ToString('o')
    AsOfUtc               = $asOfUtc.ToString('o')
    NewUsersOnboarded     = $newUserCount
}
