$AdminUsername = Get-Content './blastuser.api'
$AdminPassword = Get-Content './blastpass.api'
$location = "East US"
$subscription = (Get-AzSubscription -TenantId $tenant | where-object -Property "State" -eq "Enabled"| select-object -Property Id)
$VMName = 'BlastBox'
$resourceGroupName = 'BlastBox'
$myip = curl 'http://ifconfig.me/ip'
$pubName = 'BlastBox-IP'
$nsgName = 'BlastBox-NSG'
$vnetName = 'BlastBox-VNET'
$subnetName = 'BlastBox-SubNet'
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

$ip.IpAddress | mstsc
# az group delete --name $ResourceGroupName --yes