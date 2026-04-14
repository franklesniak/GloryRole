Set-StrictMode -Version Latest

function Get-AzActivityAdminEvent {
    # .SYNOPSIS
    # Collects canonical admin events from Azure Activity Log across
    # subscriptions with adaptive time slicing.
    # .DESCRIPTION
    # Retrieves Azure Activity Log records via Get-AzActivityLog for one or
    # more subscriptions, converting each to a CanonicalAdminEvent. Splits
    # time windows adaptively when a segment returns near the record
    # ceiling to reduce truncation risk.
    #
    # This function does NOT throw on per-subscription or per-segment
    # failures. If Set-AzContext fails for a subscription, a non-terminating
    # error is written and the subscription is skipped. If a time-segment
    # query fails, a warning is written and the segment is skipped.
    # Callers that need to halt on any failure should use -ErrorAction Stop.
    # .PARAMETER Start
    # The start of the time range to query.
    # .PARAMETER End
    # The end of the time range to query.
    # .PARAMETER SubscriptionIds
    # One or more Azure subscription IDs to query.
    # .PARAMETER InitialSliceHours
    # The initial time slice width in hours. Default is 24.
    # .PARAMETER MinSliceMinutes
    # The minimum time slice width in minutes before stopping subdivision.
    # Default is 15.
    # .PARAMETER MaxRecordHint
    # The maximum record count hint passed to Get-AzActivityLog. If a
    # slice returns this many records, the window is subdivided.
    # Default is 5000.
    # .PARAMETER DetailedOutput
    # If specified, passes -DetailedOutput to Get-AzActivityLog.
    # .EXAMPLE
    # $arrEvents = @(Get-AzActivityAdminEvent -Start (Get-Date).AddDays(-30) -End (Get-Date) -SubscriptionIds @('sub-1'))
    # # Retrieves all successful admin events for the last 30 days from a
    # # single subscription and wraps the call in @() to guarantee an array
    # # result.
    # .EXAMPLE
    # $arrEvents = @(Get-AzActivityAdminEvent -Start (Get-Date).AddDays(-7) -End (Get-Date) -SubscriptionIds @('sub-1', 'sub-2') -InitialSliceHours 6 -MinSliceMinutes 5)
    # # Queries two subscriptions over the last 7 days with narrower time
    # # slices (6-hour initial windows, 5-minute minimum). Narrower slices
    # # can improve data completeness when large volumes of events are
    # # expected.
    # .EXAMPLE
    # $arrEvents = @(Get-AzActivityAdminEvent -Start (Get-Date).AddDays(-30) -End (Get-Date) -SubscriptionIds @('sub-1') -DetailedOutput)
    # # Passes the -DetailedOutput switch through to Get-AzActivityLog,
    # # which returns additional record fields such as claims and HTTP
    # # request details.
    # .INPUTS
    # None. You cannot pipe objects to this function.
    # .OUTPUTS
    # [pscustomobject] CanonicalAdminEvent objects streamed to the pipeline.
    # .NOTES
    # Requires Az.Accounts and Az.Monitor modules.
    # Requires ConvertFrom-AzActivityLogRecord to be loaded.
    #
    # Supported on Windows PowerShell 5.1 (.NET Framework 4.6.2+) and
    # PowerShell 7.4.x / 7.5.x / 7.6.x (Windows, macOS, Linux).
    #
    # This function supports positional parameters:
    #   Position 0: Start
    #   Position 1: End
    #   Position 2: SubscriptionIds
    #
    # Version: 1.2.20260413.2

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory = $true)]
        [datetime]$Start,

        [Parameter(Mandatory = $true)]
        [datetime]$End,

        [Parameter(Mandatory = $true)]
        [string[]]$SubscriptionIds,

        [int]$InitialSliceHours = 24,
        [int]$MinSliceMinutes = 15,
        [int]$MaxRecordHint = 5000,
        [switch]$DetailedOutput
    )

    process {
        foreach ($strSubscriptionId in $SubscriptionIds) {
            Write-Verbose ("Processing subscription: {0}" -f $strSubscriptionId)

            # Az.Accounts emits "Unable to acquire token for tenant '' with
            # error 'SharedTokenCacheCredential authentication failed'"
            # warnings while probing the credential chain, even when a later
            # credential type (e.g., Azure CLI or Interactive Browser)
            # successfully acquires a token. These warnings alarm users but
            # do not indicate a real failure: genuine auth failures still
            # throw a terminating error that we catch below. Suppress the
            # probing warnings so only real problems surface to the user.
            $objVerbosePreferenceAtStartOfBlock = $VerbosePreference
            try {
                $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
                [void](Set-AzContext -SubscriptionId $strSubscriptionId -ErrorAction Stop -WarningAction SilentlyContinue)
                $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
            } catch {
                Write-Debug ("Set-AzContext failed for subscription: {0}" -f $_.Exception.Message)
                Write-Error ("Failed to set Azure context for subscription {0}: {1}" -f $strSubscriptionId, $_.Exception.Message)
                continue
            } finally {
                $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
            }

            $dateCursor = $Start
            while ($dateCursor -lt $End) {
                $dateSliceEnd = $dateCursor.AddHours($InitialSliceHours)
                if ($dateSliceEnd -gt $End) {
                    $dateSliceEnd = $End
                }

                $objStack = New-Object System.Collections.Generic.Stack[pscustomobject]
                [void]($objStack.Push([pscustomobject]@{
                            S = $dateCursor
                            E = $dateSliceEnd
                            Minutes = ($dateSliceEnd - $dateCursor).TotalMinutes
                        }))

                while ($objStack.Count -gt 0) {
                    $objSegment = $objStack.Pop()

                    $hashParams = @{
                        StartTime = $objSegment.S
                        EndTime = $objSegment.E
                        MaxRecord = $MaxRecordHint
                        WarningAction = 'SilentlyContinue'
                        ErrorAction = 'Stop'
                    }
                    if ($DetailedOutput) {
                        $hashParams['DetailedOutput'] = $true
                    }

                    $objVerbosePreferenceAtStartOfBlock = $VerbosePreference
                    try {
                        $VerbosePreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
                        $arrRaw = @(Get-AzActivityLog @hashParams)
                        $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
                    } catch {
                        Write-Debug ("Get-AzActivityLog query failed: {0}" -f $_.Exception.Message)
                        Write-Warning ("Failed to query activity log for segment {0} to {1}: {2}" -f $objSegment.S, $objSegment.E, $_.Exception.Message)
                        continue
                    } finally {
                        $VerbosePreference = $objVerbosePreferenceAtStartOfBlock
                    }

                    if ($arrRaw.Count -ge $MaxRecordHint -and $objSegment.Minutes -gt $MinSliceMinutes) {
                        $dateMid = $objSegment.S.AddMinutes($objSegment.Minutes / 2)
                        [void]($objStack.Push([pscustomobject]@{
                                    S = $dateMid
                                    E = $objSegment.E
                                    Minutes = ($objSegment.E - $dateMid).TotalMinutes
                                }))
                        [void]($objStack.Push([pscustomobject]@{
                                    S = $objSegment.S
                                    E = $dateMid
                                    Minutes = ($dateMid - $objSegment.S).TotalMinutes
                                }))
                        continue
                    }

                    foreach ($objRecord in $arrRaw) {
                        $objEvent = ConvertFrom-AzActivityLogRecord -Record $objRecord
                        if ($null -eq $objEvent) {
                            continue
                        }
                        if ($objEvent.Status -ne 'Succeeded') {
                            continue
                        }
                        $objEvent
                    }
                }

                $dateCursor = $dateSliceEnd
            }
        }
    }
}
