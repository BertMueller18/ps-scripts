#requires -version 2
<#
.SYNOPSIS
  Locates unlicensed users that have an existing mailbox. Useful for hybrid mirgations. 

.DESCRIPTION
  <Brief description of script>

.PARAMETER Domain
    Required parameter. Domain in which to search for users and mailboxes.

.INPUTS
  Parameters above

.OUTPUTS
  Returns SPLATed set of user objects and primary smtp addresses.

.NOTES
  Version:        1.0
  Author:         Jared McArthur
  Creation Date:  14/03/2015
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
#. ".\Connect_Functions.ps1"

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
      $users = get-msoluser -all | ? { !$_.isLicensed -and $_.UserPrincipalName -like "*$domain*" }
      #return @($users | % { foreach ( $i in 0..($_.count-1) ) { get-mailbox -Identity $_[$i].userprincipalname.split('@')[0] | ? {$_.primarysmtpaddress -like "*@safeplace.org" } } })
      
      return $users
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "  GetUnlicensed Completed Successfully."
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
      $smtp = @($users | % { $_ | % { if ( $_.startswith("SMTP") ) { $_.substring(5)} } })
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "  GetPrimarySMTP Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

Function Main{
  Param(
    [Parameter(Mandatory=$true)][string]$domain
  )
  
  Begin{
    Log-Write -LogPath $sLogFile -LineValue "Begin query on $domain"
  }
  
  Process{
    Try{
      $users = GetUnlicensed $domain
      $smtp =  GetPrimarySMTP $users.proxyaddresses
      return @{
        users = $users
        smtp = $smtp
      }
    }
    
    Catch{
      Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True
      Break
    }
  }
  
  End{
    If($?){
      Log-Write -LogPath $sLogFile -LineValue "Main Completed Successfully."
      Log-Write -LogPath $sLogFile -LineValue " "
    }
  }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

#Log-Start -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#main $domain

#Log-Finish -LogPath $sLogFile