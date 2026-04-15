Set-StrictMode -Version Latest

function Import-PrincipalActionCountFromCsv {
    # .SYNOPSIS
    # Imports principal-action count sparse triples from a local CSV file.
    # .DESCRIPTION
    # Reads a CSV file containing PrincipalKey, Action, and Count columns
    # and returns PrincipalActionCount sparse triples. Actions are
    # normalized during import; the normalization strategy depends on the
    # target RoleSchema:
    #   - `AzureRbac` (default): trim whitespace and lowercase via
    #     `ConvertTo-NormalizedAction` (Azure RBAC actions are
    #     case-insensitive, so lowercasing is the canonical form used for
    #     comparison and aggregation).
    #   - `EntraId`: trim whitespace only; **do not** change case. Entra
    #     ID `microsoft.directory/*` actions preserve camelCase segments
    #     (e.g., `microsoft.directory/oAuth2PermissionGrants/allProperties/update`,
    #     `microsoft.directory/servicePrincipals/standard/read`), and the
    #     Microsoft Graph `unifiedRoleDefinition` API will reject role
    #     definitions whose `allowedResourceActions` have been downcased.
    # This is the recommended ingestion mode for deterministic demos and
    # CI testing.
    # .PARAMETER Path
    # The path to the CSV file containing sparse triples.
    # .PARAMETER RoleSchema
    # Selects the action normalization strategy used during import.
    # Valid values are `AzureRbac` (lowercase + trim; default, preserves
    # the historical behavior) and `EntraId` (trim only; preserves
    # camelCase `microsoft.directory/*` segments).
    # .EXAMPLE
    # $arrCounts = @(Import-PrincipalActionCountFromCsv -Path (Join-Path -Path $HOME -ChildPath 'data/principal_action_counts.csv'))
    # # $arrCounts[0].PrincipalKey  # e.g., 'user@contoso.com'
    # # $arrCounts[0].Action        # e.g., 'microsoft.compute/virtualmachines/read'
    # # $arrCounts[0].Count         # e.g., 42
    # # Each output object is a sparse triple with PrincipalKey, Action,
    # # and Count properties. Defaults to RoleSchema 'AzureRbac' so
    # # actions are trimmed and lowercased.
    # .EXAMPLE
    # $arrCounts = @(Import-PrincipalActionCountFromCsv -Path (Join-Path -Path $HOME -ChildPath 'data/entra_counts.csv') -RoleSchema EntraId)
    # # $arrCounts[0].Action        # e.g., 'microsoft.directory/oAuth2PermissionGrants/allProperties/update'
    # # With -RoleSchema EntraId, camelCase segments in Entra ID
    # # microsoft.directory/* actions are preserved end-to-end, so the
    # # emitted unifiedRoleDefinition JSON is accepted by Microsoft Graph.
    # .EXAMPLE
    # $arrCounts = @(Import-PrincipalActionCountFromCsv -Path '.\nonexistent.csv')
    # # Throws "CSV file not found: .\nonexistent.csv" because the file does not exist.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] PrincipalActionCount sparse triples with properties:
    #   - PrincipalKey ([string]): The identity key for the principal.
    #   - Action ([string]): The normalized action string (lowercased +
    #     trimmed for `AzureRbac`; trimmed only for `EntraId`).
    #   - Count ([double]): The numeric count for this principal-action pair.
    # .NOTES
    # The CSV file MUST have columns: PrincipalKey, Action, Count.
    # Requires ConvertTo-NormalizedAction to be loaded when RoleSchema is
    # 'AzureRbac'.
    #
    # Supported PowerShell versions:
    #   - Windows PowerShell 5.1 (.NET Framework 4.6.2+)
    #   - PowerShell 7.4.x
    #   - PowerShell 7.5.x
    #   - PowerShell 7.6.x
    # Supported operating systems:
    #   - Windows (all supported PowerShell versions)
    #   - macOS (PowerShell 7.x only)
    #   - Linux (PowerShell 7.x only)
    #
    # This function supports positional parameters:
    #   Position 0: Path
    #
    # Version: 1.2.20260415.0

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('AzureRbac', 'EntraId')]
        [string]$RoleSchema = 'AzureRbac'
    )

    process {
        Write-Verbose ("Importing principal-action counts from: {0} (RoleSchema: {1})" -f $Path, $RoleSchema)

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw ("CSV file not found: {0}" -f $Path)
        }

        try {
            $arrRows = Import-Csv -LiteralPath $Path -ErrorAction Stop

            Write-Verbose ("{0} rows loaded from CSV." -f @($arrRows).Count)

            foreach ($objRow in $arrRows) {
                $strRawAction = [string]$objRow.Action
                if ($RoleSchema -eq 'EntraId') {
                    # Preserve case for Entra ID microsoft.directory/*
                    # actions (camelCase segments are significant). Only
                    # trim whitespace and skip empty entries.
                    if ([string]::IsNullOrWhiteSpace($strRawAction)) {
                        Write-Debug "Skipping row: action is empty or whitespace."
                        continue
                    }
                    $strAction = $strRawAction.Trim()
                } else {
                    # AzureRbac: lowercase + trim via the standard
                    # normalizer (Azure RBAC actions are
                    # case-insensitive).
                    $strAction = ConvertTo-NormalizedAction -Action $strRawAction
                    if ([string]::IsNullOrWhiteSpace($strAction)) {
                        Write-Debug "Skipping row: action is empty or whitespace after normalization."
                        continue
                    }
                }

                [pscustomobject]@{
                    PrincipalKey = [string]$objRow.PrincipalKey
                    Action = $strAction
                    Count = [double]$objRow.Count
                }
            }
        } catch {
            $strErrorMessage = $null
            if ($null -ne $_ -and $null -ne $_.Exception -and
                -not [string]::IsNullOrEmpty($_.Exception.Message)) {
                $strErrorMessage = $_.Exception.Message
            } else {
                $strErrorMessage = ($_ | Out-String)
            }
            Write-Debug ("Import-PrincipalActionCountFromCsv failed: {0}" -f $strErrorMessage)
            throw
        }
    }
}
