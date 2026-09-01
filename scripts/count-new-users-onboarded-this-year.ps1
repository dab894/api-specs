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

$asOfUtc = $AsOf.ToUniversalTime()
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

[pscustomobject]@{
    Year                  = $asOfUtc.Year
    StartOfYearUtc        = $startOfYearUtc.ToString('o')
    AsOfUtc               = $asOfUtc.ToString('o')
    NewUsersOnboarded     = $newUserCount
}
