<#
.SYNOPSIS
Counts identities created from the start of the current year through an as-of timestamp.

.DESCRIPTION
Uses the SailPoint PowerShell SDK search APIs to query the identities index for records
whose created timestamp is in the current calendar year and outputs the total count.

.PARAMETER AsOf
Upper bound timestamp for the calculation. Unspecified DateTime values are treated as UTC.

.PARAMETER PageSize
Number of search results requested per page.

.PARAMETER MaxResults
Maximum number of identities to retrieve while counting. If the dataset exceeds this value,
the count is capped and a warning is emitted.
#>
[CmdletBinding()]
param(
    [datetime]$AsOf = (Get-Date).ToUniversalTime(),
    [int]$PageSize = 250,
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
    "query": "*"
  },
  "filters": {
    "created": {
      "type": "RANGE",
      "range": {
        "lower": {
          "value": "$($startOfYearUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
          "inclusive": true
        },
        "upper": {
          "value": "$($asOfUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
          "inclusive": true
        }
      }
    }
  }
}
"@

$search = ConvertFrom-JsonToSearch -Json $searchJson
$results = Invoke-PaginateSearch -Search $search -Increment $PageSize -Limit $MaxResults

$newUserCount = @($results).Count

if ($newUserCount -ge $MaxResults) {
    Write-Warning "Returned count reached MaxResults=$MaxResults. Increase MaxResults if your tenant has more new users this year."
}

[pscustomobject]@{
    Year                  = $asOfUtc.Year
    StartOfYearUtc        = $startOfYearUtc.ToString('o')
    AsOfUtc               = $asOfUtc.ToString('o')
    NewUsersOnboarded     = $newUserCount
}
