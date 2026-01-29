<#  
##########################################################################################################################################
.TITLE          :   ACT migration

.FUNCTION       :       Script used if you would like to change application groups delivery groups mapping in applicationgroup.yml file
                       
                        
.PARAMETERS     :    
             		 $csvpath: path to the CSV file used for correlation source deliveryGroup (sources) and target deliverygroups (Cibles) : CSV format: Sources,Cibles
                         $applmicationpath: path to the applicationgroup.yml file to process
                         $scriptpath: path to the root directory  to store logs and output file applicationgroup.yml
.       

.REQUIEREMENTS  :     
                     Install-Module -Name powershell-yaml

.EXAMPLE        :
                        RenameDG for application groups:
                        .\RenameDG for AppGroups.ps1
   

.AUTHOR        :     Vincent Rombau - Solution Architect - Citrix 

.VERSION       : 	 1.0

.HISTORY       :    29th January 2026 - V1.0 - Initial version

#> 
[string]$csvPath = "C:\GitHub\ACT\CorrepDG-ACT.csv"
[string]$ApplicationPath = "C:\GitHub\ACT\ApplicationGroup.yml"

        $ErrorActionPreference = "Stop"
#$Scriptpath = Split-Path $MyInvocation.MyCommand.Path
        $Scriptpath = 'C:\GitHub\ACT\'
        # Create log files
        $logDir = $Scriptpath+'_Groups'+$(get-date -format yyyy-MM-dd-hh-mm)
        if ((test-path $logDir) -ne "True") {$null = New-Item $LogDir -Type Directory}
        $DGRename  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_APPGroup_DGChange.csv")
        Add-Content -Path $DGRename -Value ("ApplicationGroupName,OldDGName,NewDGName")
        $DGRemovedFromApp  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_APPGroup_DGRemove.log")
        Add-Content -Path $DGRemovedFromApp -Value ("ApplicationGroupName,OldDGName")
        $NoChange  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_APPGroup_Unchanged.log")
        Add-Content -Path $NoChange -Value ("ApplicationName")
        $AppDeleted  =  Join-Path $logDir ("$(get-date -format yyyy-MM-dd-hh-mm)_APPGroup_Deleted.log")
        Add-Content -Path $AppDeleted -Value ("ApplicationGroupName")
        # create result file
        $resultpath = $Scriptpath+'\Result'
        if ((test-path $resultpath) -ne "True") {$null = New-Item $Scriptpath\Result -Type Directory}

$path  =  $logdir+"\Applicationgroup.yml"


$dgcorrelation = Import-Csv $csvpath
$ymlGroup= Get-Content -Path $ApplicationPath -Raw

$applicationgroups = ($ymlGroup | ConvertFrom-Yaml)
$Applicationgroupsdata=$applicationgroups.ApplicationGroupData

foreach ($application in @($Applicationgroupsdata)){
        $deliverygroups = $application.DeliveryGroups
        [boolean] $deliverygroupmatch = $false # check if we have at least one match in the delievry group list
                
        foreach ($deliverygroup in @($deliverygroups)){
                #$deliverygroup = $deliverygroups[0]
                [string]$oldName = $deliverygroup.Name
                [string]$newName = ($dgcorrelation |where-object {$_.Sources -contains $oldName}).Cibles  #find in table if any match for the source deliverygroup and return the destination deliverygroup
                if (![String]::IsNullOrEmpty($newname)){  #if there is a match, rename the delivery group
                        Write-Host "Renaming Delivery Group from $oldName to $newName in application $($application.Name)"
                        Add-Content -Path $DGRename -Value ($($application.Name)+','+$oldName+','+$newName)
                        $deliverygroup.Name = $newName
                        $deliverygroupmatch = $true
                }
                else{ #if there is no match, check if the delivery group exist
                        if (![String]::IsNullOrEmpty($oldname)){  #if the delivery group is declared for the application, remove the delivery group from the list
                                Write-Host "$oldName as no match found in correlation table. This DG has been removed from the Delivery Group list for $($application.Name)" -ForegroundColor Red
                                Add-Content -Path $DGRemovedFromApp -Value ($($application.Name)+','+$oldName)
                                $deliverygroups.Remove($deliverygroup) | Out-Null
                        }
                        else{
                                Write-Host "Application $($application.Name) Not Associated to delivery group(s) only - No changes" -ForegroundColor Blue
                                 Add-Content -Path $NoChange -Value ($($application.Name))

                        }
                }
        }

        if (!$deliverygroupmatch){
                Write-Host "Warning: Application Group $($application.Name) has no more delivery groups associated. Application Group will not be migrated." -ForegroundColor Red
                Add-Content -Path $AppDeleted -Value ($($application.Name))
                $applicationGroupsdata.Remove($application) | Out-Null
        }

        else{
                # new delivery groups assigned to application
                $application.deliverygroups = $deliverygroups
        }
}

foreach ($application in $Applicationgroupsdata){
        Add-Content -Path $path -Value ("- Name: '$($application.Name)'")
        if ($application.AssociatedUserNames){
                Add-Content -Path $path -Value ("  AssociatedUserNames:")
                foreach ($username in $application.AssociatedUserNames){
                        Add-Content -Path $path -Value ("  - $($username)")
                }
        }
        Add-Content -Path $path -Value ("  Description: '$($application.Description)'")
        Add-Content -Path $path -Value ("  Enabled: $(($application.Enabled.ToString()).ToLower())")
        if ($application.RestrictToTag){Add-Content -Path $path -Value ("  RestrictToTag: '$($application.RestrictToTag)'")}
        if (![string]::IsNullOrEmpty($application.Scopes)){
                Add-Content -Path $path -Value ("  Scopes:")
                foreach ($scope in $application.Scopes){
                        Add-Content -Path $path -Value ("  - $($scope)")
                }
        }
        if ($application.SessionSharingEnabled){Add-Content -Path $path -Value ("  SessionSharingEnabled: $($application.SessionSharingEnabled.ToString().ToLower())")}

        if (![string]::IsNullOrEmpty($application.Tags)){
                Add-Content -Path $path -Value ("  Tags:")
                foreach ($tag in $application.Tags){
                        Add-Content -Path $path -Value ("  - $($Tag)")
                }
        }
        if ($application.UserFilterEnabled) {Add-Content -Path $path -Value ("  UserFilterEnabled: $(($application.UserFilterEnabled.ToString()).ToLower())")}
        
        if (![string]::IsNullOrEmpty($application.DeliveryGroups.Name)){
                Add-Content -Path $path -Value ("  DeliveryGroups:")
                foreach ($deliverygroup in $application.DeliveryGroups){
                        Add-Content -Path $path -Value ("  - Name: '$($deliverygroup.Name)'")
                        if (![string]::IsNullOrEmpty($deliverygroup.Priority)) {Add-Content -Path $path -Value ("    Priority: '$($deliverygroup.Priority)'")}
                }
        }
}







