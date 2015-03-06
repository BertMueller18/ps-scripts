<#
.SYNOPSIS
	Queries migration batch for errors on users

.DESCRIPTION
	Script for identifying migration failures to Exchange Online / Office 365

.PARAMETER	noecho
	Call script with the -noecho flag to suppress output.

.PARAMETER noexport
    Call script with the -noexport flag to suppress CSV generation

.PARAMETER path
    Supply a path along with the -path flag to direct output to a specified location. If no path is provided, or it doesn't exist, the pwd will be used.

.PARAMETER simulate
    Call script with the -simulate flag to run all aspects of the script except the main info gathering cmdlet. This flag is for testing/debugging only.

.NOTES
	Version:		1.0
	Author:			Jared McArthur
	Creation Date:	3/5/2015
	Purpose/Change:	Initial script development
	GitHub:		https://github.com/ascensionra
	Twitter:	https://twitter.com/redtailnetworks

#>

param([switch]$noecho, [switch]$noexport, [string[]]$path, [switch]$simulate)

$filename = $null
$Session = $null
$LiveCred = $null

function connect365
{
    if (-not $simulate -and -not $Session) 
    {
	    $LiveCred = Get-Credential
    }

    if (-not $simulate)
    {
	    write-host -foregroundcolor White "Attempting to establish session with provided credentials."
        
	    do
	    {
		    try
		    {
                $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $LiveCred -Authentication Basic -AllowRedirection -ErrorAction STOP
                $stopLoop = $true
            }
            catch
		    {
			    if ($retry -eq 3)
			    {
				    write-host -foregroundcolor Red "3 login failures. Exiting."
                    return
				    #exit
			    }
			    else
			    {
				    write-host -ForegroundColor Yellow "Bad credentials"
				    $retry++
				    $LiveCred = Get-Credential
			    }
		    }
	    } while ($stopLoop -eq $false)

        Import-PSSession $Session -AllowClobber
    }
    elseif (-not $simulate)
    { 
	    write-host -foregroundcolor Yellow "`$Session already exists"
    }
}

Function printResults
{
    $failures | more
    write-host -foregroundcolor Red "`nFound a total of" $failures.count "failed users/mailboxes"
}

Function exportResults
{
    write-host -ForegroundColor Red "Found" $failures.count "failed users/mailboxes"
    
    if (-not $simulate)
    {
        $failures | Export-Csv $filename
    }
}

Function generateOutFilename($path)
{
    $date = Get-Date
    $shortDate = (Write-Output $date.Month $date.Day $date.Year) -join "-"
    if ($path)
    {
    	$filename = ($path).Trim() + ("\failures_").Trim() + ($shortDate) + (".csv").trim()
    }
    else
    {
    	$filename = ".\failures_" + $shortDate + ".csv"
    }
    #write-host -foregroundcolor Cyan "`nExporting list to CSV as $filename"
    return $filename
}

Function testFlags
{
    if ($simulate)
    {
        write-host -ForegroundColor Cyan "`nSimulating only"
    }
    if ($noecho -and $noexport)
    { 
        write-host -foregroundcolor Yellow "`nNo output, what's the point? Exiting.`n" 
        exit
    }

    if ($noecho)
    {
        write-host -ForegroundColor Yellow "`nExporting results only"
    }

    if ($noexport)
    {
        write-host -ForegroundColor Yellow "`nNo export requested"
    }

    if ($path -and -not $noexport)
    {
        if (-not (test-path $path))
        {
            write-host -ForegroundColor Yellow "`nNonexistent directory supplied. Creating..."
            New-Item -Path $path -ItemType Directory
        }
        else
        {
            #$filename = generateOutFilename($path) 
            Write-host -ForegroundColor Yellow "`nExporting csv to" $filename
        }
    }
    elseif (-not $noexport)
    {
        write-host -ForegroundColor Yellow "`nUsing current directory" (Get-Item -path ".\" -verbose).FullName
    }
    #return $filename
}

function main
{
    $filename = generateOutFilename

    if (Test-Path "D:\Users\Jared\Documents\git\ps-scripts\SecureCreds.xml")
    {
        write-host -ForegroundColor Green "`nImporting existing credentials"
        $LiveCred = Import-Clixml "D:\Users\Jared\Documents\git\ps-scripts\SecureCreds.xml"
    }
    
    testFlags

<# Debug block
    if ($filename -ne $null -and $simulate)
    {
        write-host "Again, using $filename"
    }
#>
    $stopLoop = $false
    [int]$retry = "0"

    if ($LiveCred -eq $null)
    {
        write-host -ForegroundColor White "`nConnecting to 365"
        connect365
    }
    else
    {
        write-host -ForegroundColor Magenta "`nSession already exists, continuing"
    }

    write-host -foregroundcolor White "`nConnecting to MSOL"

    if(-not $simulate -or $LiveCred -ne $null)
    {
        Connect-MsolService -Credential $LiveCred
    }

    write-host -foregroundcolor Green "`nChecking for migration failures"

    if (-not $simulate)
    {
        $failures = Get-MigrationUser | ? { $_.status -eq "Failed" } | % { Get-MigrationUserStatistics -Identity $_.identity | select Identity,Error }
    }
    else
    {
        $failures = 1
    }

    if ($failures -ne $null)
    {
        if (-not $noecho)
        { printResults }

        if (-not $noexport)
        { exportResults }
    }
    else
    {
	    write-host -foregroundcolor Green "`nNo failures"	
    }	

    write-host -foregroundcolor White "`nRemoving PS Session"
    if ($Session -ne $null)
    {
        remove-pssession $Session
    }

    write-host -foregroundcolor White "`n**** Finished, press any key to exit."
    $x = $host.ui.rawui.ReadKey("NoEcho,IncludeKeyDown")
}

main
