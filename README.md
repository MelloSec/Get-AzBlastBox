# Get-AzBlastBox

## A set of disposable VMs configured for development or testing. 


#### Get-AzBlastBox is the powershell version. I was aiming for idempotence and immutability, so I used powershell scripts to automate the configuration of the hosts and captured those images to Azure in a gallery. I have base images, Windows 10 or Server 2019, then layers, like common tools, then dev tools, then specialized dev tools. Visual Studio, Visual Studio with Cloud tools, Malware tools, etc.

#### The script takes a desired name and image, gets your subscription, checks for the resource groups existence and if it's not found begins creating the resources. Where it made sense I had it continue to do these checks for each resource.  It creates all resources with the name you specified earlier + "-RG" "-VNET" etc. It pulls your public IP address and creates rules to open the Network Security Group for you for web, RDP and PsRemote. 

#### It wants to pull the IP of the VM and open RDP to that port but we aren't there yet

The Az-BlastBox-Create is the Azure CLI version that started this, a simpler but less dynamic one. Good in a pinch!

TODO:
- [ ] Automatically RDP to the public IP address of the machine, its pulling a different public IP now and I'm not sure what's going on there
- [ ] Make the parameters more functional so we can select the image, opened ports
