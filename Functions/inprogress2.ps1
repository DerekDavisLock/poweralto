<#

$update = $true
$version = "4.1.9"


if ($Update) { $UpdateCheck = Send-PaApiQuery -Op "<request><system><software><check></check></software></system></request>" }

Update-PaContent





    if ($Versioninfo.current -eq "no") {
        $xpath = "<request><system><software><install><version>$Version</version></install></software></system></request>"
        $Install = Send-PaApiQuery -Op $xpath
        $Job = [decimal]($Install.response.result.job)
        $Status = Watch-PaJob -j $job -c "Installing $Version"
    }
} else {
    throw $VersionInfo.response.msg
}


$LatestVersion = $UpdateSoftware.response.result."sw-updates".versions.entry | where { $_.latest -eq "yes" }
$LatestBase = $LatestVersion.version.Substring(0,3)
$CurrentVersion = (Get-PaSystemInfo)."sw-version"
$CurrentBase = $CurrentVersion.Substring(0,3)
#>


$Version = "latest"
if ($Version -eq "latest") {
    $UpdateCheck = Send-PaApiQuery -Op "<request><system><software><check></check></software></system></request>"
    if ($UpdateCheck.response.status -eq "success") {
        $VersionInfo = Send-PaApiQuery -Op "<request><system><software><info></info></software></system></request>"
        
        $Version = $VersionInfo.response.result."sw-updates".versions.entry | where { $_.latest -eq "yes" }
    }
}
$Version



Function Get-Stepping ( [String]$Version ) {
    $Stepping = @()
    $UpdateCheck = Send-PaApiQuery -Op "<request><system><software><check></check></software></system></request>"
    if ($UpdateCheck.response.status -eq "success") {
        $VersionInfo = Send-PaApiQuery -Op "<request><system><software><info></info></software></system></request>"
        $AllVersions = $VersionInfo.response.result."sw-updates".versions.entry
        $DesiredVersion = $AllVersions | where { $_.version -eq "$Version" }
        if (!($DesiredVersion)) { return "version not listed" }
        $DesiredBase = $DesiredVersion.version.Substring(0,3)
        $CurrentVersion = (Get-PaSystemInfo)."sw-version"
        $CurrentBase = $CurrentVersion.Substring(0,3)
        if ($CurrentBase -eq $DesiredBase) {
            $Stepping += $Version
        } else {
            foreach ($v in $AllVersions) {
                $Step = $v.version.Substring(0,3)
                if (($Stepping -notcontains "$Step.0") -and ("$Step.0" -ne "$CurrentBase.0") -and ($Step -le $DesiredBase)) {
                    $Stepping += "$Step.0"
                }
            }
            $Stepping += $Version
        }
        set-variable -name pacom -value $true -scope 1
        return $Stepping | sort
    } else {
        return $UpdateCheck.response.msg.line
    }
}

Function Download-Update ( [Parameter(Mandatory=$True)][String]$Version ) {
    $VersionInfo = Send-PaApiQuery -Op "<request><system><software><info></info></software></system></request>"
    if ($VersionInfo.response.status -eq "success") {
        $DesiredVersion = $VersionInfo.response.result."sw-updates".versions.entry | where { $_.version -eq "$Version" }
        if ($DesiredVersion.downloaded -eq "no") {
            $Download = Send-PaApiQuery -Op "<request><system><software><download><version>$($DesiredVersion.version)</version></download></software></system></request>"
            $job = [decimal]($Download.response.result.job)
            $Status = Watch-PaJob -j $job -c "Downloading $($DesiredVersion.version)" -s $DesiredVersion.size
            if ($Status.response.result.job.result -eq "FAIL") {
                return $Status.response.result.job.details.line
            }
            set-variable -name pacom -value $true -scope 1
            return $Status
        } else {
            set-variable -name pacom -value $true -scope 1
            return "PanOS $Version already downloaded"
        }
    } else {
        throw $VersionInfo.response.msg.line
    }
}

Function Install-Update ( [Parameter(Mandatory=$True)][String]$Version ) {
    $VersionInfo = Send-PaApiQuery -Op "<request><system><software><info></info></software></system></request>"
    if ($VersionInfo.response.status -eq "success") {
        $DesiredVersion = $VersionInfo.response.result."sw-updates".versions.entry | where { $_.version -eq "$Version" }
        if ($DesiredVersion.downloaded -eq "no") { "PanOS $Version not downloaded" }
        if ($DesiredVersion.current -eq "no") {
            $xpath = "<request><system><software><install><version>$Version</version></install></software></system></request>"
            $Install = Send-PaApiQuery -Op $xpath
            $Job = [decimal]($Install.response.result.job)
            $Status = Watch-PaJob -j $job -c "Installing $Version"
            if ($Status.response.result.job.result -eq "FAIL") {
                return $Status.response.result.job.details.line
            }
            set-variable -name pacom -value $true -scope 1
            return $Status
        } else {
            set-variable -name pacom -value $true -scope 1
            return "PanOS $Version already installed"
        }
    } else {
        return $VersionInfo.response.msg.line
    }
}
<#
while ($global:stepping -ne "success") {
    $test = Get-Stepping "5.0.1-h1"
    $test
}

foreach ($t in $test) {
    Download-Update $t
}

foreach ($t in $test) {
    Install-Update $t
    sleep 30
    Restart-PaSystem
}

$pacom = $false
while (!($pacom)) {
    $UpdateCheck = Send-PaApiQuery -Op "<request><system><software><check></check></software></system></request>"
    install-update "4.1.6"
}
#>

$pacom = $false
while (!($pacom)) {
    $Steps = Get-Stepping "5.0.1-h1"
    $Steps
}

foreach ($s in $Steps) {
    $pacom = $false
    "downloading $s"
    while (!($pacom)) {
        $Download = Download-Update $s
    }
}

foreach ($s in $Steps) {
    $pacom = $false
    "installing $s"
    while (!($pacom)) {
        $Install = Install-Update $s
    }
    Restart-PaSystem
}