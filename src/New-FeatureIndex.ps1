Set-StrictMode -Version Latest

function New-FeatureIndex {
    # .SYNOPSIS
    # Creates a stable, sorted feature index for fixed-length numeric
    # vector representation of principal-action data.
    # .DESCRIPTION
    # In machine learning, a **feature** is a measurable property or
    # attribute used as input to a model. In this role-mining pipeline,
    # each unique Azure action name (e.g.,
    # "microsoft.compute/virtualmachines/read") is a feature.
    #
    # A **feature index** is a mapping that assigns each feature a stable
    # integer position so that every data point can be represented as a
    # fixed-length numeric vector. This is essential because most
    # clustering and classification algorithms require fixed-dimension
    # numeric input.
    #
    # This function extracts all unique action names from the supplied
    # sparse triples, sorts them alphabetically, and creates a hashtable
    # mapping each action to its integer index position. The alphabetical
    # sort ensures reproducible, fixed-length vector dimensions across
    # runs.
    # .PARAMETER PrincipalActionCounts
    # An array of PrincipalActionCount sparse triples.
    # .EXAMPLE
    # $objIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts
    # # $objIndex.FeatureNames = @('microsoft.compute/virtualmachines/delete', ...)
    # # $objIndex.FeatureIndex = @{ 'microsoft.compute/virtualmachines/delete' = 0; ... }
    # .EXAMPLE
    # $arrCounts = @(
    #     [pscustomobject]@{ PrincipalKey = 'user1'; Action = 'read'; Count = 3.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'read'; Count = 1.0 }
    #     [pscustomobject]@{ PrincipalKey = 'user2'; Action = 'write'; Count = 2.0 }
    # )
    # $objIndex = New-FeatureIndex -PrincipalActionCounts $arrCounts
    # # $objIndex.FeatureNames.Count
    # # # Returns 2 (not 3), because 'read' appears under both principals
    # # # but is deduplicated to a single feature.
    # # $objIndex.FeatureIndex
    # # # @{ 'read' = 0; 'write' = 1 }
    #
    # # Demonstrates deduplication: even though three input objects exist,
    # # the feature index contains only the two unique action names.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] An object with FeatureNames (sorted action array)
    # and FeatureIndex (action-to-index hashtable).
    # .NOTES
    # Version: 2.0.20260412.0
    # Supported PowerShell versions:
    #   - Windows PowerShell 5.1 (.NET Framework 4.6.2+)
    #   - PowerShell 7.4.x
    #   - PowerShell 7.5.x
    #   - PowerShell 7.6.x
    # Supported operating systems:
    #   - Windows (all supported PowerShell versions)
    #   - macOS (PowerShell 7.x only)
    #   - Linux (PowerShell 7.x only)
    # This function supports positional parameters:
    #   Position 0: PrincipalActionCounts

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The "New-" verb constructs an in-memory index object; no external or system state is modified, so ShouldProcess support is not applicable.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [object[]]$PrincipalActionCounts
    )

    process {
        try {
            Write-Verbose -Message ("Extracting unique features from {0} sparse triples..." -f $PrincipalActionCounts.Count)

            $arrFeatures = @($PrincipalActionCounts |
                    Select-Object -ExpandProperty Action |
                    Sort-Object -Unique)

            Write-Debug -Message ("Feature index internal state: {0} input counts, {1} unique features so far." -f $PrincipalActionCounts.Count, $arrFeatures.Count)

            $hashIndex = @{}
            for ($intIndex = 0; $intIndex -lt $arrFeatures.Count; $intIndex++) {
                $hashIndex[[string]$arrFeatures[$intIndex]] = $intIndex
            }

            Write-Verbose -Message ("Feature index built: {0} unique features." -f $arrFeatures.Count)

            [pscustomobject]@{
                FeatureNames = $arrFeatures
                FeatureIndex = $hashIndex
            }
        } catch {
            Write-Debug -Message ("Feature index build failed: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
