<#
.SYNOPSIS
    Unattended XML generator for offline OOBE bypass and WinSwift integration.
.DESCRIPTION
    Generates an autounattend.xml file that skips the Microsoft Account
    requirement, disables OOBE telemetry prompts, and optionally pre-seeds
    WinSwift to run on first boot.
    Created by Bios-System | https://github.com/BiosSystem/WinSwift
#>

function Generate-UnattendXML {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$OutputPath = "C:\autounattend.xml"
    )

    Write-Host "> Generating autounattend.xml for offline OOBE bypass..." -ForegroundColor Cyan

    $xmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <NetworkLocation>Home</NetworkLocation>
            </OOBE>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
"@

    if ($PSCmdlet.ShouldProcess($OutputPath, "Create autounattend.xml file")) {
        try {
            $xmlContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
            Write-Host "  [OK] Generated Unattend XML at: $OutputPath"
            Write-Host "  To use: Place this file on the root of your Windows 11 installation USB." -ForegroundColor Yellow
        } catch {
            Write-Host "  [WARN] Failed to generate XML: $_" -ForegroundColor Yellow
        }
    }

    Write-Host ""
}

