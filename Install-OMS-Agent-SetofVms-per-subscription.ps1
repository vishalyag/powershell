# Script Description - This script installs the OMS agent on Azure VMs by going through all the resource groups for a single subscription
#Suppress the warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
#Connect-AzAccount
$sub_id = Read-Host "Provide subscription Id of the Azure environment: -"
az account set --subscription $sub_id
#Defining variables
$i=0
$workspace_rg = "az-monitor-rg"
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $workspace_rg
$workspaceId = $workspace.CustomerId
$workspaceKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $workspace_rg -Name $workspace.Name
$Publicsettings=@{"workspaceId" = $workspaceId}
$Protectedsettings=@{"workspaceKey" = $workspaceKey.primarysharedkey}

# Get the excluded VMs Property and counts of such Vms
$exclude_vms = Import-Csv "E:\vms3.csv"
$exclude_vm_list = $exclude_vms | ForEach-Object {
    foreach ($property in $_.PSObject.Properties) {
        $property.Name
        $property.Value
        #replace = $property.Value
        }
    }
$fl_exclude_vm_list = $exclude_vm_list.length
# Get the resource Groups and export the details to a file
$rgs = Get-AzResourceGroup | Select-Object -Property ResourceGroupName | Export-Csv "E:\rgs.csv"
$file = Import-Csv "E:\rgs.csv"

# Get the Resource Groups Property and counts of such RGs
$filevalues = $file | ForEach-Object {
    foreach ($property in $_.PSObject.Properties) {
        #$property.Name
        $property.Value
        #replace = $property.Value
        }
    }

$fl = $filevalues.length
for ($i=0;$i -lt $fl;$i++) {
    $rg = $filevalues[$i]
    $vms=Get-AzVM -ResourceGroupName $rg
    #Write-Host "Vms are $vms"
    if ($vms -eq $null) {
        Write-Host "No VMs present in the Resource Group $rg"
    }
    else {
        foreach($vm in $vms){
            $vmName=$vm.name
            $vmLocation = $vm.Location
            $vmostype = $vm.StorageProfile.OsDisk.OsType
            $vmextstate = Get-AzVMExtension -ResourceGroupName $rg -VMName $vmName
            $exc_vm = $exclude_vm_list | Select-String $vmName
            if ( $exc_vm ) {
                Write-Host "VM $vmName present in the Resource Group $rg of OS Type $vmostype needs to be excluded from the Azure monitor Integration"
                }
            else {
                if ($vmostype -eq "Linux") {
                    Set-AzVMExtension -ExtensionName "OmsExtension" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "OmsAgentForLinux" -TypeHandlerVersion 1.13 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
                    #Set-AzVMExtension -ExtensionName "Microsoft.Azure.Monitoring.DependencyAgent" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.Azure.Monitoring.DependencyAgent" -ExtensionType "DependencyAgentLinux" -TypeHandlerVersion 9.5 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
                    }
                else {
                    Set-AzVMExtension -ExtensionName "Microsoft.EnterpriseCloud.Monitoring" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "MicrosoftMonitoringAgent" -TypeHandlerVersion 1.0 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
                    #Set-AzVMExtension -ExtensionName "Microsoft.Azure.Monitoring.DependencyAgent" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.Azure.Monitoring.DependencyAgent" -ExtensionType "DependencyAgentWindows" -TypeHandlerVersion 9.5 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
                }
            }

        }
    }
}