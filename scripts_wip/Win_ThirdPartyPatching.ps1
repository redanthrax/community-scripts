<#
.SYNOPSIS
.DESCRIPTION
.EXAMPLE
.NOTES
    Version: 1.0
    Author: red
    Created Date: 2024-03-19
#>

Param(

)

function Win_ThirdPartyPatching {
    [CmdletBinding()]
    Param (

    )

    Begin {
        $error.Clear()
        Write-Output "Setting up prereqs"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        #get winget from build
        $wingetDir = "C:\Program Files\winget"
        $wingetDownload = "https://github.com/redanthrax/winget-cli/releases/download/1.0/winget.zip"
        if (-Not(Test-Path $wingetDir)) {
            New-Item -ItemType Directory -Force -Path $wingetDir
        }

        if (-Not(Test-Path -PathType Leaf -Path "$wingetDir\winget.exe")) {
            Write-Output "Downloading winget binary"
            Invoke-WebRequest -Uri $wingetDownload -OutFile "$wingetDir\winget.zip"
            Expand-Archive -Path "$wingetDir\winget.zip" -DestinationPath $wingetDir
        }


        #Install runasuser
        if (!(Get-Module RunAsUser)) {
            Write-Output "Installing RunAsUser"
            Install-PackageProvider -Name NuGet -Force | Out-Null
            Install-Module -Name RunAsUser -Force -SkipPublisherCheck
            Import-Module -Name RunAsUser -Force
        }

        if (-Not(Test-Path 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes')) {
            #Install vsruntime
            Write-Output "Installing required VS Runtime"
            $runtime = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
            Invoke-WebRequest -Uri $runtime -OutFile "$wingetDir\vs_redist.x64.exe"
            $runArgs = "/q", "/norestart"
            Start-Process -FilePath "$wingetDir\vs_redist.x64.exe" -ArgumentList $runArgs -Wait | Out-Null
        }

        Write-Output "Prereqs passed"
    }

    Process {
        Try {
            Write-Output "Doing updates as system"
            $procargs = @("upgrade", "--accept-source-agreements", "--accept-package-agreements", "--all", "--force")
            Start-Process -FilePath "C:\Program Files\winget\winget.exe" -ArgumentList $procargs -WindowStyle Hidden -PassThru -Wait | Out-Null
            Write-Output "Doing updates as user" 
            $userScript = {
                $procargs = @("upgrade", "--accept-source-agreements", "--accept-package-agreements", "--all", "--force")
                Start-Process -FilePath "C:\Program Files\winget\winget.exe" -ArgumentList $procargs -WindowStyle Hidden -PassThru -Wait | Out-Null
            }

            Invoke-AsCurrentUser -ScriptBlock $userScript | Out-Null
            Write-Output "Update check complete"
        }
        Catch {
            Write-Error $_.Exception
        }
    }

    End {
        if ($error) {
            $error
            Exit 1
        }

        Exit 0
    }
}

if (-Not(Get-Command 'Win_ThirdPartyPatching' -ErrorAction SilentlyContinue)) {
    . $MyInvocation.MyCommand.Path
}


$scriptArgs = @{

}

Win_ThirdPartyPatching @scriptArgs