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
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        #get winget from build
        $wingetDir = "C:\Program Files\winget"
        $wingetDownload = "https://github.com/redanthrax/winget-cli/releases/download/1.0/winget.zip"
        if (-Not(Test-Path $wingetDir)) {
            New-Item -ItemType Directory -Force -Path $wingetDir
        }

        if (-Not(Test-Path -PathType Leaf -Path "$wingetDir\winget.exe")) {
            Invoke-WebRequest -Uri $wingetDownload -OutFile "$wingetDir\winget.zip"
            Expand-Archive -Path "$wingetDir\winget.zip" -DestinationPath $wingetDir
        }

        #Install runasuser
        if (!(Get-Module RunAsUser)) {
            Install-Module -Name RunAsUser -Force -SkipPublisherCheck
            Import-Module -Name RunAsUser -Force
        }

        #Install vsruntime
        $runtime = "https://aka.ms/vs/16/release/vc_redist.x64.exe"
        Invoke-WebRequest -Uri $runtime -OutFile "$wingetDir\vs_redist.x64.exe"
        $runArgs = "/q","/norestart"
        $proc = Start-Process -FilePath "$wingetDir\vs_redist.x64.exe" -ArgumentList $runArgs -Wait
        $proc
    }

    Process {
        Try {
            #TODO: update as system
            $wingetArgs = "upgrade"
            Start-Process -FilePath "$wingetDir\winget.exe" -ArgumentList $wingetArgs -Wait

            #TODO: update as user
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