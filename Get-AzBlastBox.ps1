#TODO If not moduled installed, imported, 
#TODO if not account connected already connect-azaccoint

# Install-Module Az
# Import-Module Az
# Connect-AzAccount

$location = "East US"
$subscription = (Get-AzSubscription -TenantId $tenant | where-object -Property "State" -eq "Enabled"| select-object -Property Id)
$VMName = 'BlastBox'
$resourceGroupName = -join("$VMName","-RG")
$myip = curl 'http://ifconfig.me/ip'
$VNETName = -join("$VMName","-VNET")
$pubName = -join("$VMName","-IP")
$nsgName = -join("$VMName","-NSG")
$subnetName = -join("$VMName","-Subnet")
$gallery1 = Get-AzGallery -ResourceGroupName 'Images' -Name 'DevBoxes'
$Server2019 = get-azgalleryimageversion -galleryname $gallery1.Name -resourcegroupname $gallery1.ResourceGroupName -galleryImageDefinitionName 'DevServer2019'
$VS2019 = get-azgalleryimageversion -galleryname $gallery1.Name -resourcegroupname $gallery1.ResourceGroupName -galleryImageDefinitionName 'VS2019'
$MalwareDev = get-azgalleryimageversion -galleryname $gallery1.Name -resourcegroupname $gallery1.ResourceGroupName -galleryImageDefinitionName 'MalwareDev'
$CloudDev = get-azgalleryimageversion -galleryname $gallery1.Name -resourcegroupname $gallery1.ResourceGroupName -galleryImageDefinitionName 'CloudDev'

# Select which Image to use, this gets used in the creation of the VM function later on. We should figure out how to do it better, with parameters on that function and a default value to malwaredev
$image = $MalwareDev


# Check to see if the resource group exists, if it doesn't it will create it. If it does, the script will ask if you want to add it into the existing group or not.
function Create-RG {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String]$resourceGroupName,
      [Parameter(Mandatory)]
      [String]$location
  )
  if(!(Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue))
  { 
    New-AzResourceGroup -name $resourceGroupName -location $location 
  }
}
$rg = Create-RG $resourceGroupName $location

  # Using our current host's public ip, we create and open NSG rules allowing RDP, SSH and HTTP/s traffic from that source address 
function Allow-RDP {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String]$ip 
  )
      New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" `
      -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix `
      "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
}
$rule1 = Allow-RDP $myip

function Allow-HTTP {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip 
  )
      New-AzNetworkSecurityRuleConfig -Name http-rule -Description "Allow HTTP" `
      -Access Allow -Protocol Tcp -Direction Inbound -Priority 102 -SourceAddressPrefix `
      "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
}
$rule2 = Allow-HTTP $myip

function Allow-HTTPS {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip 
  )
      New-AzNetworkSecurityRuleConfig -Name https-rule -Description "Allow HTTPs" `
      -Access Allow -Protocol Tcp -Direction Inbound -Priority 103 -SourceAddressPrefix `
      "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
}
$rule3 = Allow-HTTPS $myip

function Allow-Custom {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip,
      [Parameter(Mandatory)] 
      [String] $port
  )
      New-AzNetworkSecurityRuleConfig -Name custom-rule -Description "Allow Custom NSG rules" `
      -Access Allow -Protocol Tcp -Direction Inbound -Priority 104 -SourceAddressPrefix `
      "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $port;
      Write-Output "Opening $port for $ip"
}
$rule4 = Allow-Custom -ip $myip -port 22 

# Create and set the Network Security Group
# TODO Splat these
function Create-NSG {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String]$resourceGroupName,
      [Parameter(Mandatory)] 
      [String]$location
  )
  if(!(Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name NSG-FrontEnd -ErrorAction SilentlyContinue))
      {
      $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name NSG-FrontEnd -SecurityRules $rule1,$rule2,$rule3 
      $nsg | Set-AzNetworkSecurityGroup
      }
}
$nsg = Create-NSG $resourceGroupName $location
# Create Networking Resources and configure
# TODO Add parameter bindings to the function
function Create-Networking {
    $frontendSubnet       = New-AzVirtualNetworkSubnetConfig -Name FrontEnd -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroup $nsg
    $backendSubnet        = New-AzVirtualNetworkSubnetConfig -Name BackEnd  -AddressPrefix "10.0.2.0/24" -NetworkSecurityGroup $nsg
    $subName              = $frontendSubnet.name
    New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $frontendSubnet,$backendSubnet
  }
Create-Networking

$PIP = New-AzPublicIpAddress -Name $pubName -DomainNameLabel $VMName.tolower() -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic
function Create-VM {
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]$image
  )
  if(!(Get-AzVm -Name $VMName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue))`
    { 
      $vm = New-AzVm -Name $VMName -ResourceGroupName $resourceGroupName `
      -Size Standard_B2ms -VirtualNetworkName $VNetName -SubnetName Subnet -SecurityGroupName $nsgName `
      -ImageReferenceId $image -PublicIpAddressName $pubName -NetworkInterfaceDeleteOption Delete -OSDiskDeleteOption Delete 
    }
}
$vm = Create-VM $image.Id

# Grab IP of VM and open RDP to that address
$VM = get-azvm -name $VMName -resourcegroupname $resourcegroupName
$ip = $VM | Get-AzPublicIpAddress

# Create a function to grab your test Resource Group and trash it. 
# When you're done, just type "Clean-Up" in the terminal, powershell will grab the RG we just created and destroy it
function Clean-Up {
  Get-AzVm -Name $VMName -ResourceGroupName $resourceGroupName | Remove-AzVm -ForceDeletion $true
  Get-AzVirtualNetwork -Name $VNETName | Remove-AzVirtualNetwork -force
  Get-AzNetworkSecurityGroup -Name $nsgName | Remove-AzNetworkSecurityGroup -Force
  Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup -Force
}

