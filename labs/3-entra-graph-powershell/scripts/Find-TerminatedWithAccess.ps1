<#
.SYNOPSIS
    Finds Microsoft Entra ID accounts that the directory believes have already left,
    but which still hold group memberships.

.DESCRIPTION
    An off-boarding control. It answers the question an auditor actually asks:
    "prove that everyone who left no longer has access."

    The naive version of this check looks for terminated users whose accounts are still
    enabled. That check is wrong, and this script deliberately does not use it. Disabling
    an account does not remove its access. A disabled account keeps its group memberships,
    its licenses, and its access package assignments, and anything that re-enables it
    restores all of that instantly.

    So the rule here is "terminated but still entitled," not "terminated but still enabled."
    Account state is reported as a column, not used as a filter.

.NOTES
    Author : Mukhtar Houry
    Lab    : Entra Lab 3 - Identity Automation with Microsoft Graph PowerShell

    REQUIRED PERMISSIONS
        User.Read.All
        User-LifeCycleInfo.Read.All   <- see warning below
        Group.Read.All

    THE User-LifeCycleInfo TRAP
        employeeLeaveDateTime is gated behind its own consent scope. It is NOT covered by
        User.Read.All. Without it, Microsoft Graph returns the property EMPTY rather than
        returning an access denied error.

        That means a session missing this one permission produces a clean, complete-looking
        report with every leave date blank, and an administrator would reasonably conclude
        no one in the tenant has ever been offboarded.

        This script therefore refuses to run unless the scope is present. A null lifecycle
        attribute is not evidence of anything unless you have confirmed you were allowed to
        read it.

    KNOWN LIMITATION - THIS IS A POINT IN TIME CHECK
        Graph returns current state only. The directory does not retain membership history,
        so this script cannot tell you what access someone held on their termination date,
        and it cannot detect an offboarding failure that has since been reversed or repaired.

        Run it on a schedule. A finding that self-heals overnight leaves no trace on the user
        object, and Entra audit log retention is 30 days on P2 and 7 days on the free tier.

.EXAMPLE
    ./Find-TerminatedWithAccess.ps1

.EXAMPLE
    ./Find-TerminatedWithAccess.ps1 | Export-Csv -Path offboarding-review.csv -NoTypeInformation

    Produces evidence you can hand to an auditor.
#>

# ---------------------------------------------------------------------------
# 1. Confirm we are connected, and that we hold the permissions this check needs
# ---------------------------------------------------------------------------

$context = Get-MgContext

if (-not $context) {
    Write-Error "Not connected to Microsoft Graph. Run Connect-MgGraph first."
    return
}

$requiredScopes = @(
    'User.Read.All',
    'User-LifeCycleInfo.Read.All',
    'Group.Read.All'
)

$missingScopes = $requiredScopes | Where-Object { $_ -notin $context.Scopes }

if ($missingScopes) {
    Write-Error @"
Missing required permissions: $($missingScopes -join ', ')

Results would be silently incomplete rather than obviously wrong, so this script will not run.
Reconnect with:

Connect-MgGraph -Scopes "User.Read.All","User-LifeCycleInfo.Read.All","Group.Read.All"
"@
    return
}

Write-Host "Connected as $($context.Account) with all required permissions." -ForegroundColor Green
Write-Host "Checking for terminated identities that still hold access...`n"

# ---------------------------------------------------------------------------
# 2. Pull every user, along with the lifecycle attributes we care about
# ---------------------------------------------------------------------------
# Graph does not return every property by default. Anything not named here comes back
# empty, which is a separate way to get a misleadingly clean result.

$allUsers = Get-MgUser -All -Property "id,displayName,userPrincipalName,accountEnabled,department,employeeLeaveDateTime"

# ---------------------------------------------------------------------------
# 3. Keep only the users the directory believes have already left
# ---------------------------------------------------------------------------
# Note what is NOT in this filter: accountEnabled. That omission is the whole point.

$departed = $allUsers | Where-Object {
    $_.EmployeeLeaveDateTime -ne $null -and
    $_.EmployeeLeaveDateTime -lt (Get-Date)
}

# ---------------------------------------------------------------------------
# 4. For each departed user, look up what access they still hold
# ---------------------------------------------------------------------------

$findings = foreach ($user in $departed) {

    # memberOf returns groups AND directory roles AND administrative units.
    # Filter to groups so the count means what it says.
    $memberships = @(Get-MgUserMemberOf -UserId $user.Id -All | Where-Object {
        $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group'
    })

    $groupNames = ($memberships | ForEach-Object { $_.AdditionalProperties.displayName }) -join ', '

    [PSCustomObject]@{
        Name           = $user.DisplayName
        UPN            = $user.UserPrincipalName
        AccountEnabled = $user.AccountEnabled
        Department     = $user.Department
        LeaveDate      = $user.EmployeeLeaveDateTime
        DaysSinceLeave = [int]((Get-Date) - $user.EmployeeLeaveDateTime).TotalDays
        GroupCount     = $memberships.Count
        Groups         = $groupNames
    }
}

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------

$stillEntitled = @($findings | Where-Object { $_.GroupCount -gt 0 })

if ($stillEntitled.Count -eq 0) {
    Write-Host "No terminated identities are holding group memberships." -ForegroundColor Green
} else {
    Write-Host "$($stillEntitled.Count) terminated identity(s) still hold group access:`n" -ForegroundColor Yellow
    $stillEntitled | Format-Table Name, AccountEnabled, Department, LeaveDate, DaysSinceLeave, GroupCount, Groups -AutoSize
}

# Emit the objects so the caller can pipe them to Export-Csv or anything else.
$stillEntitled
