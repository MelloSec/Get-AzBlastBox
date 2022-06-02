Import-Module Az

$AdminUsername = Get-Content "./blastuser.api"
$AdminPassword = Get-Content "./blastpass.api"
$location = "East US"
$subscription = (Get-AzSubscription -TenantId $tenant | where-object -Property "State" -eq "Enabled"| select-object -Property Id)
$VMName = 'BlastBox'
$resourceGroupName = -join("$VMName","-RG")
$myip = curl 'http://ifconfig.me/ip'
$VNETName = -join("$VMName","-VNET")
$gallery = Get-AzGallery -ResourceGroupName MELLONAUT -Name malwaremachines
$image = get-azgalleryimageversion -galleryname malwaremachines -resourcegroupname mellonaut -galleryImageDefinitionName malwaredevelopment
$imageid = $image.Id.tostring()
$pubName = -join("$VMName","-IP")
$nsgName = -join("$VMName","-NSG")
$subnetName = -join("$VMName","-Subnet")
$malwareDev = Get-Content "./malwaredev.api"


# Check to see if the resource group exists, if it doesn't it will create it. If it does, the script will ask if you want to add it into the existing group or not.
$rg = if(!(Get-AzResourceGroup -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue))
  { New-AzResourceGroup -name $resourceGroupName -location $location }

# Create our NSG Rules

function Allow-RDP{
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip 
  )
  New-AzNetworkSecurityRuleConfig -Name http-rule -Description "Allow RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix `
    "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389;
    Write-Output 'Opening ports for "$ip"'
}
$rule1 = Allow-Rdp $myip

function Allow-HTTP{
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip 
  )
  New-AzNetworkSecurityRuleConfig -Name http-rule -Description "Allow HTTP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 102 -SourceAddressPrefix `
    "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80;
    Write-Output 'Opening ports for "$ip"'
}
$rule2 = Allow-HTTP $myip

function Allow-HTTPS{
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip 
  )
  New-AzNetworkSecurityRuleConfig -Name http-rule -Description "Allow HTTP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 103 -SourceAddressPrefix `
    "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443;
    Write-Output 'Opening ports for "$ip"'
}
$rule3 = Allow-HTTPs $myip

function Allow-Custom{
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory)]
      [String] $ip, 
      [String] $port
  )
  New-AzNetworkSecurityRuleConfig -Name http-rule -Description "Allow Custom NSG rules" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 104 -SourceAddressPrefix `
    "$ip" -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $port;
    Write-Output "Opening $port for $ip"
}
$rule4 = Allow-Custom -ip $myip -port $port 

# Create and set the Network Security Group
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name `
    "NSG-FrontEnd" -SecurityRules $rule1,$rule2,$rule3 
$nsg | Set-AzNetworkSecurityGroup

# Create our Networking
# TODO Add parameter bindings to the function
function Create-Networking {
    $frontendSubnet       = New-AzVirtualNetworkSubnetConfig -Name FrontEnd -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroup $nsg
    $backendSubnet        = New-AzVirtualNetworkSubnetConfig -Name BackEnd  -AddressPrefix "10.0.2.0/24" -NetworkSecurityGroup $nsg
    New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $frontendSubnet,$backendSubnet
}
Create-Networking


# Create the VM with the CLI since PoSh won't take the custom image string / some osProfile error
$vm = az vm create --resource-group $resourceGroupName --vnet-name $VNetName --subnet $frontendSubnet.name --nsg $nsg.name --name $VMName --admin-username $AdminUsername --admin-password $AdminPassword --public-ip-sku Standard --image  --specialize 


# Grab IP of VM and open RDP to that address
$ip = Get-AzPublicIpAddress -Name $pubip
$ip.Name | mstsc 


# Create a function to grab your test Resource Group and trash it. 
# When you're done with it, just type "Clean-Up" in the terminal, powershell will grab the RG we just created and destroy it
function Clean-Up {
  Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup
}

