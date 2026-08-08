<#
.SYNOPSIS
    Finds Microsoft Entra ID accounts that the directory believes have already left,
    but which still hold access of any kind.

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

    ENTITLEMENT IS CHECKED IN THREE PLACES, NOT ONE
        Groups                  the obvious one, and the only one most checks look at
        Licenses                a cost leak as well as an access one, and the step that
                                gets forgotten for months
        Access package assignments
                                approved, governed access. It survives independently of
                                group membership and has its own expiration clock.

        A user can be clean on all three, or clean on groups and dirty on the other two.
        Reporting only groups produces a confident, incomplete answer.

.NOTES
    Author : Mukhtar Houry
    Lab    : Entra Lab 3 - Identity Automation with Microsoft Graph PowerShell

    REQUIRED PERMISSIONS
        User.Read.All                   user objects
        User-LifeCycleInfo.Read.All     employeeLeaveDateTime   <- see warning below
        Group.Read.All                  group memberships
        EntitlementManagement.Read.All  access package assignments
        Organization.Read.All           license SKU names

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

    EXCESS PERMISSIONS ARE ALSO REPORTED
        Connect-MgGraph -Scopes is a request, not a limit. Entra returns a token carrying
        every delegated permission the application has already been consented for, so a
        session opened "read-only" can still hold tenant-wide write.

        Under-permission produces a silently wrong report. Over-permission produces silent
        risk. This script warns about the second without refusing to run, because excess
        privilege does not corrupt the results, it just should not go unnoticed.

    KNOWN LIMITATION - THIS IS A POINT IN TIME CHECK
        Graph returns current state only. The directory does not retain membership history,
        so this script cannot tell you what access someone held on their termination date,
        and it cannot detect an offboarding failure that has since been reversed or repaired.

        Run it on a schedule. A finding that self-heals overnight leaves no trace on the user
        object, and Entra audit log retention is 30 days on P2 and 7 days on the free tier.

.PARAMETER PassThru
    Emit the finding objects instead of printing the human-readable report. Use this when
    piping to Export-Csv or another cmdlet. Without it the script prints a report and emits
    nothing, so an interactive run does not show the same data twice.

.EXAMPLE
    ./Find-TerminatedWithAccess.ps1

    Human-readable report.

.EXAMPLE
    ./Find-TerminatedWithAccess.ps1 -PassThru | Export-Csv -Path offboarding-review.csv -NoTypeInformation

    Produces evidence you can hand to an auditor.
#>

[CmdletBinding()]
param(
    [switch]$PassThru
)

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
    'Group.Read.All',
    'EntitlementManagement.Read.All',
    'Organization.Read.All'
)

$missingScopes = $requiredScopes | Where-Object { $_ -notin $context.Scopes }

if ($missingScopes) {
    Write-Error @"
Missing required permissions: $($missingScopes -join ', ')

Results would be silently incomplete rather than obviously wrong, so this script will not run.
Reconnect with:

Connect-MgGraph -Scopes "$($requiredScopes -join '","')"
"@
    return
}

# Excess privilege: warn, do not block. It does not corrupt results, but a session that
# holds write when the operator believes it is read-only should never be silent.
$writeScopes = @($context.Scopes | Where-Object { $_ -like '*ReadWrite*' -or $_ -like '*.Write.*' })

if ($writeScopes.Count -gt 0) {
    Write-Warning @"
This session holds WRITE permissions that this read-only audit does not need:
    $($writeScopes -join "`n    ")

Connect-MgGraph -Scopes is a request, not a limit. Entra returns every scope the application
has already been consented for. Check the standing admin consent grant under
Enterprise applications > Microsoft Graph Command Line Tools > Permissions.
"@
}

Write-Host "Connected as $($context.Account) with all required permissions." -ForegroundColor Green
Write-Host "Checking for terminated identities that still hold access...`n"

# ---------------------------------------------------------------------------
# 2. Build a SKU lookup so licenses report as names, not GUIDs
# ---------------------------------------------------------------------------
# assignedLicenses on a user returns skuId only. Nobody can read a report of GUIDs.

$skuLookup = @{}
try {
    Get-MgSubscribedSku -All | ForEach-Object { $skuLookup[$_.SkuId] = $_.SkuPartNumber }
} catch {
    Write-Warning "Could not read subscribed SKUs, licenses will report as GUIDs. $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# 3. Pull every user, along with the lifecycle attributes we care about
# ---------------------------------------------------------------------------
# Graph does not return every property by default. Anything not named here comes back
# empty, which is a separate way to get a misleadingly clean result.

$allUsers = Get-MgUser -All -Property "id,displayName,userPrincipalName,accountEnabled,department,employeeLeaveDateTime,assignedLicenses"

# ---------------------------------------------------------------------------
# 4. Keep only the users the directory believes have already left
# ---------------------------------------------------------------------------
# Note what is NOT in this filter: accountEnabled. That omission is the whole point.

$departed = $allUsers | Where-Object {
    $null -ne $_.EmployeeLeaveDateTime -and
    $_.EmployeeLeaveDateTime -lt (Get-Date)
}

if (@($departed).Count -eq 0) {
    Write-Host "No users in this tenant carry a past employeeLeaveDateTime." -ForegroundColor Green
    Write-Host "Note: that is only meaningful because the lifecycle scope was confirmed above."
    return
}

Write-Host "$(@($departed).Count) terminated identity(s) found. Checking entitlements...`n"

# ---------------------------------------------------------------------------
# 5. For each departed user, look up every kind of access they still hold
# ---------------------------------------------------------------------------

$findings = foreach ($user in $departed) {

    # --- groups -------------------------------------------------------------
    # memberOf returns groups AND directory roles AND administrative units.
    # Filter to groups so the count means what it says.
    $memberships = @(Get-MgUserMemberOf -UserId $user.Id -All | Where-Object {
        $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group'
    })
    $groupNames = ($memberships | ForEach-Object { $_.AdditionalProperties.displayName }) -join ', '

    # --- licenses -----------------------------------------------------------
    # An access control and a cost control at the same time.
    $licenses = @($user.AssignedLicenses | ForEach-Object {
        if ($skuLookup.ContainsKey($_.SkuId)) { $skuLookup[$_.SkuId] } else { $_.SkuId }
    })
    $licenseNames = $licenses -join ', '

    # --- access package assignments ----------------------------------------
    # Governed, approved access with its own lifecycle. Independent of group membership.
    $packages = @()
    try {
        $packages = @(
            Get-MgEntitlementManagementAssignment -Filter "target/objectId eq '$($user.Id)'" -ExpandProperty accessPackage -All |
                Where-Object { $_.State -eq 'Delivered' }
        )
    } catch {
        Write-Warning "Access package lookup failed for $($user.UserPrincipalName): $($_.Exception.Message)"
    }
    $packageNames = ($packages | ForEach-Object { $_.AccessPackage.DisplayName }) -join ', '

    [PSCustomObject]@{
        Name           = $user.DisplayName
        UPN            = $user.UserPrincipalName
        AccountEnabled = $user.AccountEnabled
        Department     = $user.Department
        LeaveDate      = $user.EmployeeLeaveDateTime
        # Floor, not round. A bare [int] cast rounds, so 2.6 days would report as 3 and 12
        # hours would report as 1 day. On an audit column, overstating how long someone has
        # held access after termination is the wrong direction to be wrong in.
        # The outer [int] is not redundant: [math]::Floor returns a double, which renders
        # as "2.000" in a table.
        DaysSinceLeave = [int][math]::Floor(((Get-Date) - $user.EmployeeLeaveDateTime).TotalDays)
        GroupCount     = $memberships.Count
        Groups         = $groupNames
        LicenseCount   = $licenses.Count
        Licenses       = $licenseNames
        PackageCount   = $packages.Count
        AccessPackages = $packageNames
    }
}

# ---------------------------------------------------------------------------
# 6. Report
# ---------------------------------------------------------------------------
# "Still entitled" means ANY of the three, not just groups. A user clean on groups and
# holding a license is still a failed offboarding.

$stillEntitled = @($findings | Where-Object {
    $_.GroupCount -gt 0 -or $_.LicenseCount -gt 0 -or $_.PackageCount -gt 0
})

# -PassThru emits objects for piping. Without it, print the report and emit nothing, so an
# interactive run does not display the same findings twice.
if ($PassThru) {
    return $stillEntitled
}

if ($stillEntitled.Count -eq 0) {
    Write-Host "No terminated identities hold groups, licenses, or access packages." -ForegroundColor Green
} else {
    Write-Host "$($stillEntitled.Count) terminated identity(s) still hold access:`n" -ForegroundColor Yellow
    $stillEntitled |
        Format-Table Name, AccountEnabled, LeaveDate, DaysSinceLeave, GroupCount, LicenseCount, PackageCount -AutoSize

    Write-Host "Detail:`n"
    foreach ($f in $stillEntitled) {
        Write-Host "  $($f.Name)  ($($f.UPN))" -ForegroundColor Yellow
        Write-Host "    account   : $(if ($f.AccountEnabled) { 'ENABLED' } else { 'disabled' })"
        Write-Host "    left      : $($f.LeaveDate)  ($($f.DaysSinceLeave) days ago)"
        Write-Host "    groups    : $(if ($f.Groups)         { $f.Groups }         else { 'none' })"
        Write-Host "    licenses  : $(if ($f.Licenses)       { $f.Licenses }       else { 'none' })"
        Write-Host "    packages  : $(if ($f.AccessPackages) { $f.AccessPackages } else { 'none' })"
        Write-Host ''
    }
}
