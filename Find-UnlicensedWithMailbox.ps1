#requires -version 2
<#
.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER Domain
    Required parameter. Domain in which to search for users and mailboxes.

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

Param([Parameter(Mandatory=$true)][string]$domain)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

#Dot Source required Function Libraries
. ".\Logging_Functions.ps1"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$sLogPath = "."
$sLogName = "UnlicensedWithMailbox.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function GetUnlicensed{
  Param([Parameter(Mandatory=$true)][string]$domain)
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Generating array of users in provided domain."
  }
  
  Process{
    Try{
      $users = @( get-msoluser -all | ? { !$_.isLicensed -and $_.UserPrincipalName -like "*$domain*" } | select ProxyAddresses )
      #return $users
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

Function GetPrimarySMTP{
  Param([Parameter(Mandatory=$true)][string[]]$users)
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Extracting PrimarySMTP values from proxyAddresses"
  }
  
  Process{
    Try{
      $smtp = @($users | % { $_.proxyAddresses | % { if ( $_.startswith("SMTP") ) { $_.substring(5)} } })
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion
return getprimarysmtp(GetUnlicensed($domain))
Log-Finish -LogPath $sLogFile
