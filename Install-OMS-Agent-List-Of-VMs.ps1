# Script Description - This script installs the OMS agent on Azure VMs by going through all the resource groups for a single subscription
#Suppress the warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
#Connect-AzAccount
$sub_id = Read-Host "Provide subscription Id of the Azure environment: -"
Select-AzSubscription $sub_id
#Defining variables
$i=0
$vmStat1 = @()
$workspace_rg = "az-monitor-rg"
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $workspace_rg
$workspaceId = $workspace.CustomerId
$workspaceKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $workspace_rg -Name $workspace.Name
$Publicsettings=@{"workspaceId" = $workspaceId}
$Protectedsettings=@{"workspaceKey" = $workspaceKey.primarysharedkey}

$file = Import-Csv "E:\vms.csv"

foreach($vm in $file){
    $vmName=$vm.Name
    $vmLocation = $vm.Location
    $rg = $vm.ResourceGroupName
    $vmostype = (Get-AzVM -Name $vmName).StorageProfile.OsDisk.OsType
    $vmStat1= Get-AzVM -ResourceGroupName $rg -VMName $vmName -Status
    $vmStat2= $vmStat1.Statuses[-1].DisplayStatus
    if ($vmStat2 -eq "VM running")  {
        if ($vmostype -eq "Linux") {
            $ext_name = (Get-AzVMExtension -ResourceGroupName $rg -VMName $vmName).Name

            if (!$ext_name) {
                Write-Host "Linux VM found - OMS Agent Installation is in progress for the VM $vmName present in the Resource Group $rg"
                Set-AzVMExtension -ExtensionName "OmsAgentForLinux" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "OmsAgentForLinux" -TypeHandlerVersion 1.7 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
                }
            else {
                $wsp_id_vm = az vm extension show -g $rg --vm-name $vmName -n $ext_name --query settings.workspaceId -o table
                if ($wsp_id_vm -eq $workspaceId) {
                    Write-Host "Linux VM $vmName present in the Resource Group $rg is already integrated with the workspace "$workspace.Name""
                    }
                else {
                    Write-Host "Linux VM found - OMS Agent Uninstallation is in progress for the VM $vmName present in the Resource Group $rg"
                    Remove-AzVMExtension -ResourceGroupName $rg -VMName $vmName -Name $ext_name -Force
                    Write-Host "Linux VM found - OMS Agent Installation is in progress for the VM $vmName present in the Resource Group $rg"
                    Set-AzVMExtension -ExtensionName "OmsAgentForLinux" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "OmsAgentForLinux" -TypeHandlerVersion 1.7 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
                    }
                }
            }
        else {
            Write-Host "Windows VM found - Monitoring Agent Installation is in progress for the VM $vmName present in the Resource Group $rg"
            Set-AzVMExtension -ExtensionName "Microsoft.EnterpriseCloud.Monitoring" -ResourceGroupName $rg -VMName $vmName -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "MicrosoftMonitoringAgent" -TypeHandlerVersion 1.0 -Settings $PublicSettings -ProtectedSettings $ProtectedSettings -Location $vmLocation
            }
        }
    else {
        Write-Host "$vmostype VM $vmName present in the Resource Group $rg is in Powered Down State and OMS agent cannot be installed"
        }
    }