@{
    RootModule        = 'GloryRole.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b1b25c49-16ae-4c61-a09a-b4bd2d4fe0a0'
    Author            = 'Frank Lesniak and Danny Stutz'
    CompanyName       = 'Community'
    Copyright         = 'Copyright (c) 2026 Frank Lesniak and Danny Stutz'
    Description       = 'An unsupervised role mining engine written in PowerShell. Feed it cloud activity logs and it figures out who does what, groups similar principals via K-Means clustering, and generates least-privilege custom role definitions.'
    PowerShellVersion = '5.1'

    # Functions to export — these are the module's public functions from src/
    # (excludes Invoke-RoleMiningPipeline.ps1, which is a script entry point,
    # and non-exported helper functions such as Get-EntraIdRoleDisplayName.ps1)
    FunctionsToExport = @(
        'ConvertFrom-AzActivityLogRecord'
        'ConvertFrom-ClaimsJson'
        'ConvertFrom-EntraIdAuditRecord'
        'ConvertTo-EntraIdResourceAction'
        'ConvertTo-NormalizedAction'
        'ConvertTo-NormalizedVectorRow'
        'ConvertTo-PrincipalActionCount'
        'ConvertTo-TfIdfCount'
        'ConvertTo-VectorRow'
        'Edit-ReadActionCount'
        'Get-ActionStatFromCount'
        'Get-ApproximateSilhouetteScore'
        'Get-AzActivityAdminEvent'
        'Get-CalinskiHarabaszIndex'
        'Get-ClusterActionSet'
        'Get-DaviesBouldinIndex'
        'Get-EntraIdAuditEvent'
        'Get-FarthestPointIndex'
        'Get-SquaredEuclideanDistance'
        'Get-StableSha256Hex'
        'Import-PrincipalActionCountFromCsv'
        'Import-PrincipalActionCountFromLogAnalytics'
        'Invoke-AutoKSelection'
        'Invoke-KMeansClustering'
        'Measure-PrincipalActionCountQuality'
        'New-AzureRoleDefinitionJson'
        'New-EntraIdRoleDefinitionJson'
        'New-FeatureIndex'
        'Remove-DuplicateCanonicalEvent'
        'Remove-RareAction'
        'Resolve-LocalizableStringValue'
        'Resolve-PrincipalKey'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Azure', 'RBAC', 'RoleMining', 'KMeans', 'Clustering', 'LeastPrivilege', 'Security', 'IAM', 'EntraID', 'MicrosoftGraph')
            LicenseUri   = 'https://github.com/franklesniak/GloryRole/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/franklesniak/GloryRole'
            ReleaseNotes = 'Initial release'
        }
    }
}
