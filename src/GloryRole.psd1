@{
    RootModule        = 'GloryRole.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b1b25c49-16ae-4c61-a09a-b4bd2d4fe0a0'
    Author            = 'Frank Lesniak and Danny Stutz'
    CompanyName       = 'Community'
    Copyright         = 'Copyright (c) 2026 Frank Lesniak and Danny Stutz'
    Description       = 'An unsupervised role mining engine written in PowerShell. Feed it cloud activity logs and it figures out who does what, groups similar principals via K-Means clustering, and generates least-privilege custom role definitions.'
    PowerShellVersion = '5.1'

    # Functions to export — these are the 27 function files in src/
    # (excludes Invoke-RoleMiningPipeline.ps1 which is a script entry point)
    FunctionsToExport = @(
        'ConvertFrom-AzActivityLogRecord'
        'ConvertFrom-ClaimsJson'
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
        'Get-FarthestPointIndex'
        'Get-SquaredEuclideanDistance'
        'Get-StableSha256Hex'
        'Import-PrincipalActionCountFromCsv'
        'Import-PrincipalActionCountFromLogAnalytics'
        'Invoke-AutoKSelection'
        'Invoke-KMeansClustering'
        'Measure-PrincipalActionCountQuality'
        'New-AzureRoleDefinitionJson'
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
            Tags         = @('Azure', 'RBAC', 'RoleMining', 'KMeans', 'Clustering', 'LeastPrivilege', 'Security', 'IAM')
            LicenseUri   = 'https://github.com/franklesniak/GloryRole/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/franklesniak/GloryRole'
            ReleaseNotes = 'Initial release'
        }
    }
}
