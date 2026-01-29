<#  
##########################################################################################################################################
.TITLE          :   ACT migration

.FUNCTION       :       Script used if you would like to change application delivery groups mapping in application.yml file
                       
                        
.PARAMETERS     :    
             		 $csvpath: path to the CSV file used for correlation source deliveryGroup (sources) and target deliverygroups (Cibles) : CSV format: Sources,Cibles
                         $applmicationpath: path to the application.yml file to process
                         $scriptpath: path to the root directory  to store logs and output file application.yml
.       

.REQUIEREMENTS  :     
                     Install-Module -Name powershell-yaml

.EXAMPLE        :
                        RenameDG for applications:
                        .\RenameDG for Apps.ps1  
   
   

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 1.0

.HISTORY       :    29th January 2026 - V1.0 - Initial version

#> 

[string]$csvPath = "C:\GitHub\ACT\CNAV\CorrepDG-ACT2.csv"   #format CSV: Sources,Cibles
[string]$ApplicationPath = "C:\GitHub\ACT\CNAV\Applicationcnp.yml" 

$Scriptpath = 'C:\GitHub\ACT\'


        $ErrorActionPreference = "Stop"
#       $Scriptpath = Split-Path $MyInvocation.MyCommand.Path

        # Create log files
        $logDir = $Scriptpath+'_Logs_'+$(get-date -format yyyy-MM-dd-hh-mm)
        if ((test-path $logDir) -ne "True") {$null = New-Item $LogDir -Type Directory}
        $path  =  $logdir+"\Application.yml"
        $DGRename  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_DGChange.csv")
        Add-Content -Path $DGRename -Value ("Delivery group modified for application")
        Add-Content -Path $DGRename -Value ("ApplicationName,OldDGName,NewDGName")
        $DGRemovedFromApp  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_AppRemove.log")
        Add-Content -Path $DGRemovedFromApp -Value ("Delivery groups removed from application as not present in entry table")
        Add-Content -Path $DGRemovedFromApp -Value ("ApplicationName,OldDGName")
        $NoChange  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_AppNoChange.log")
        Add-Content -Path $NoChange -Value ("Application associated to application groups only")
        $AppDeleted  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_AppDeleted.log")
        Add-Content -Path $AppDeleted -Value ("Application with no delivery group associated after routine")


$dgcorrelation = Import-Csv $csvpath


$yml= Get-Content -Path $ApplicationPath -Raw




$applications = ($yml | ConvertFrom-Yaml)
$Applicationsdata=$applications.ApplicationData

foreach ($application in @($Applicationsdata)){
        $deliverygroups = $application.DeliveryGroups
        [boolean] $deliverygroupmatch = $false # check if we have at least one match in the delievry group list
                
        foreach ($deliverygroup in @($deliverygroups)){
                #$deliverygroup = $deliverygroups[0]
                [string]$oldName = $deliverygroup.Name
                [string]$newName = ($dgcorrelation |where-object {$_.Sources -contains $oldName}).Cibles  #find in table if any match for the source deliverygroup and return the destination deliverygroup
                if (![String]::IsNullOrEmpty($newname)){  #if there is a match, rename the delivery group
                        Write-Host "Renaming Delivery Group from $oldName to $newName in application $($application.ApplicationName)"
                Add-Content -Path $DGRename -Value ($($application.ApplicationName)+','+$oldName+','+$newName)
                        $deliverygroup.Name = $newName
                        $deliverygroupmatch = $true
                }
                else{ #if there is no match, check if the delivery group exist
                        if (![String]::IsNullOrEmpty($oldname)){  #if the delivery group is declared for the application, remove the delivery group from the list
                                Write-Host "$oldName as no match found in correlation table. This DG has been removed from the Delivery Group list for $($application.ApplicationName)" -ForegroundColor Red
                Add-Content -Path $DGRemovedFromApp -Value ($($application.ApplicationName)+','+$oldName)
                                $deliverygroups.Remove($deliverygroup) | Out-Null
                        }
                        else{
                                Write-Host "Application $($application.ApplicationName) Associated to application group(s) only - No changes" -ForegroundColor Blue
                                Add-Content -Path $NoChange -Value ($($application.ApplicationName))
                                $deliverygroupmatch = $true
                        }
                }
        }

        if (!$deliverygroupmatch){
                Write-Host "Warning: Application $($application.Name) has no more delivery groups associated. Application will not be migrated." -ForegroundColor Red
        Add-Content -Path $AppDeleted -Value ($($application.ApplicationName))
                $applicationsdata.Remove($application) | Out-Null
        }                
        else{
                # new delivery groups assigned to application
                $application.deliverygroups = $deliverygroups
        }
}

Add-Content -Path $path -Value ("ApplicationData:")
foreach ($application in $applications.ApplicationData){
        Add-Content -Path $path -Value ("- Name: '$($application.Name)'")
        if (![string]::IsNullOrEmpty($application.DeliveryGroups.Name)){
                Add-Content -Path $path -Value ("  DeliveryGroups:")
                foreach ($deliverygroup in $application.DeliveryGroups){
                        Add-Content -Path $path -Value ("  - Name: '$($deliverygroup.Name)'")
                        if (![string]::IsNullOrEmpty($deliverygroup.Priority)) {Add-Content -Path $path -Value ("    Priority: '$($deliverygroup.Priority)'")}
                }
        }
       
        if (![string]::IsNullOrEmpty($application.ApplicationGroups.Name)){
                Add-Content -Path $path -Value ("  ApplicationGroups:")
                foreach ($applicationgroup in $application.ApplicationGroups){
                        Add-Content -Path $path -Value ("  - Name: '$($applicationgroup.Name)'")
                }
        }

        if (![string]::IsNullOrEmpty($application.AdminFolderName)) {Add-Content -Path $path -Value ("  AdminFolderName: '$($application.AdminFolderName)'")}
        Add-Content -Path $path -Value ("  ApplicationName: '$($application.ApplicationName)'")
        Add-Content -Path $path -Value ("  ApplicationType: '$($application.ApplicationType)'")
        Add-Content -Path $path -Value ("  PackagedApplicationType: '$($application.PackagedApplicationType)'")
        Add-Content -Path $path -Value ("  BrowserName: '$($application.BrowserName)'")
        if (![string]::IsNullOrEmpty($application.ClientFolder)) {Add-Content -Path $path -Value ("  ClientFolder: '$($application.ClientFolder)'")}
        if (![string]::IsNullOrEmpty($application.CommandLineArguments)) {Add-Content -Path $path -Value ("  CommandLineArguments: '$($application.CommandLineArguments)'")}
        Add-Content -Path $path -Value ("  CommandLineExecutable: '$($application.CommandLineExecutable)'")
        if (![string]::IsNullOrEmpty($application.ContentLocation)) {Add-Content -Path $path -Value ("  ContentLocation: $($application.ContentLocation)")}
        Add-Content -Path $path -Value ("  CpuPriorityLevel: '$($application.CpuPriorityLevel)'")
        if (![string]::IsNullOrEmpty($application.Description)) {Add-Content -Path $path -Value ("  Description: '$($application.Description)'")}

        if (![string]::IsNullOrEmpty($application.Enabled)) {Add-Content -Path $path -Value ("  Enabled: $($application.Enabled.ToString().ToLower())")}

        Add-Content -Path $path -Value ("  HomeZoneMode: '$($application.HomeZoneMode)'")
        Add-Content -Path $path -Value ("  IconUid: '$($application.IconUid)'")

        if (![string]::IsNullOrEmpty($application.MaxPerUserInstances)) {Add-Content -Path $path -Value ("  MaxPerUserInstances: $($application.MaxPerUserInstances)")}


        Add-Content -Path $path -Value ("  PublishedName: '$($application.PublishedName)'")
        if (![string]::IsNullOrEmpty($application.ShortcutAddedToDesktop)) {Add-Content -Path $path -Value ("  ShortcutAddedToDesktop: $($application.ShortcutAddedToDesktop.ToString().ToLower())")}
        if (![string]::IsNullOrEmpty($application.ShortcutAddedToStartMenu)) {Add-Content -Path $path -Value ("  ShortcutAddedToStartMenu: $($application.ShortcutAddedToStartMenu.ToString().ToLower())")}
        if (![string]::IsNullOrEmpty($application.Tags)){
                Add-Content -Path $path -Value ("  Tags:")
                foreach ($tag in $application.Tags){
                        Add-Content -Path $path -Value ("  - $($tag)")
                }
        }
        if (![string]::IsNullOrEmpty($application.UserFilterEnabled)) {Add-Content -Path $path -Value ("  UserFilterEnabled: $($application.UserFilterEnabled.ToString().ToLower())")}
        if ($application.Visible) {Add-Content -Path $path -Value ("  Visible: $($application.Visible.ToString().ToLower())")}
        if (![string]::IsNullOrEmpty($application.WaitForPrinterCreation)) {Add-Content -Path $path -Value ("  WaitForPrinterCreation: $($application.WaitForPrinterCreation.ToString().ToLower())")}
        if (![string]::IsNullOrEmpty($application.WorkingDirectory)) {Add-Content -Path $path -Value ("  WorkingDirectory: '$($application.WorkingDirectory)'")}              
        if ($application.AssociatedUserNames){
                Add-Content -Path $path -Value ("  AssociatedUserNames:")
                foreach ($username in $application.AssociatedUserNames){
                        Add-Content -Path $path -Value ("  - $($username)")
                }
        }
}
