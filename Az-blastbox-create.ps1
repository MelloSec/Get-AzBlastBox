$AdminUsername = Get-Content './blastuser.api'
$AdminPassword = Get-Content './blastpass.api'
$location = "East US"
$subscription = (Get-AzSubscription -TenantId $tenant | where-object -Property "State" -eq "Enabled"| select-object -Property Id)
$VMName = 'BlastBox-CLI'
$resourceGroupName = 'BlastBox-CLI'
$myip = curl 'http://ifconfig.me/ip'
$pubName = 'BlastBox-CLI-IP'
$nsgName = 'BlastBox-CLI-NSG'
$vnetName = 'BlastBox-CLI-VNET'
$subnetName = 'BlastBox-CLI-SubNet'
$malwareDev = Get-Content "./malwaredev.api" 



$rg = az group create --name $resourceGroupName --location $location


$vnet = az network vnet create --name $vnetName --resource-group $resourceGroupName --subnet-name "$subnetName"

$pubip = az network public-ip create --resource-group $resourceGroupName --name "$pubName" --sku Standard

$nsg = az network nsg create --name $nsgName --resource-group $resourceGroupName

$rule1 = az network nsg rule create --resource-group $resourceGroupName --nsg-name $nsgName --name AllowHTTP --access Allow --protocol Tcp --direction Inbound --priority 150 --source-address-prefix $myip --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80
$rule1 = az network nsg rule create --resource-group $resourceGroupName --nsg-name $nsgName --name AllowHTTPs --access Allow --protocol Tcp --direction Inbound --priority 151 --source-address-prefix $myip --source-port-range "*" --destination-address-prefix "*" --destination-port-range 443
$rule1 = az network nsg rule create --resource-group $resourceGroupName --nsg-name $nsgName --name AllowRDP --access Allow --protocol Tcp --direction Inbound --priority 152 --source-address-prefix $myip --source-port-range "*" --destination-address-prefix "*" --destination-port-range 3389

$vnic = az network nic create --resource-group $resourceGroupName --name 'vNIC' --vnet-name $vnet --subnet "$subnetName" --network-security-group $nsg --public-ip-address $pubip

$vm = az vm create --resource-group $resourceGroupName --name $VMName --admin-username $AdminUsername --admin-password $AdminPassword --public-ip-sku Standard --image "$malwaredev" --specialize 

$ip = Get-AzPublicIpAddress | Where-object {$_.Name -eq "$pubName"}

az vm open-port --port 3389 --resource-group $ResourceGroupName --name $VMName

az vm list-ip-address --resource-group $ResourceGroupName --name $VMName

$ip.IpAddress | mstsc

# Need to clean up the networking resources too
function Clean-Up-CLI {
    az group delete --name $resourceGroupName --yes
}