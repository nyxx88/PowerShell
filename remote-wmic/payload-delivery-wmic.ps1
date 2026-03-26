param (
    [Parameter (Mandatory=$true)] [string] $TargetHost,
    [Parameter (Mandatory=$true)] [string] $TargetUser,
    [Parameter (Mandatory=$true)] [string] $TargetPassword
)

$ScriptBlock = @'
$DownloadLink = "http://8.8.8.8/file/FalconSensor_Windows.exe"
$TempPath = $env:TEMP
$InstallerFile = "FalconSensor_Windows.exe"
$GoodSHA256 = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
$InstallParam = "/install /quiet /norestart"
$CID = "88888888888888888888888888888888-88"
$TranscriptFile = "FalconTranscript.log"
$LogFile = "FalconInstallation.log"

function Log {
  param (
    [String] $Message
  )
  $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $LogMessage = "$TimeStamp : $Message"
  Add-Content -Path "$TempPath\$LogFile" -Value $LogMessage
}

# Start session logging
Start-Transcript -Path "$TempPath\$TranscriptFile" -Append

# Download the Falcon sensor installer and save it on the %TEMP% directory
Log "Sensor download start"
Invoke-WebRequest -Uri $DownloadLink -OutFile "$TempPath\$InstallerFile"
Log "Sensor download end"

# Get the SHA256 hash
$InstallerHash = (Get-FileHash -Path "$TempPath\$InstallerFile" -Algorithm SHA256).Hash.ToLower()
Log "SHA256: $InstallerHash"

if ($InstallerHash -eq $GoodSHA256) {
  $InstallParam += " CID=$CID"
  Log "Installation start"
  $Process = (Start-Process -FilePath "$TempPath\$InstallerFile" -ArgumentList $InstallParam -PassThru -ErrorAction SilentlyContinue)
  Log "Installation Process ID: $Process.Id"
  Wait-Process -Id $Process.Id
  Log "Installation end"

  $ExitCode = $Process.ExitCode
  if ($ExitCode -ne 0) {
    # Some error happened
    Log "Exit code: $ExitCode"

    if ($ExitCode -eq 1244) {
      Log "Unable to communicate with the CrowdStrike cloud. Please check your installation token."
      Exit 1244
    }
    elseif ($ExitCode -eq 87) {
      Log "No CID value provided."
      Exit 87
    }
    else {
      Log "Installation failed"
      Exit 2
    }
  }

} else {
  Log "Corrupted hash: $InstallerHash"
  Log "Terminating"
  Exit 1
}

Stop-Transcript
'@

$Bytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptBlock)
$EncodedCommand = [System.Convert]::ToBase64String($Bytes)

$WMI_params = "/node:""$TargetHost"" /user:""$TargetUser"" /password:""$TargetPassword"" process call create ""PowerShell -NoProfile -ExecutionPolicy Bypass -EncodedCommand " + $EncodedCommand + """"

$Process = Start-Process wmic -ArgumentList $WMI_params -PassThru

Write-Output $Process
