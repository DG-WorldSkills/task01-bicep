param storageName string = 'storage${uniqueString(resourceGroup().id)}'
param sqlName string = 'sql${uniqueString(resourceGroup().id)}'

param sqlPass string

param location string = resourceGroup().location
param vmname string = 'vm1'
param vmsize string = 'Standard_B1s'
@allowed([
  'Basic'
  'Standard'
])
param publicIpAddressSku string = 'Basic'
param osDiskType string = 'Premium_LRS'
param adminUsername string
@secure()
param adminPassword string

//network card
var networkInterfaceName = '${vmname}-interface'
var publicIpName = '${vmname}-ip'
var nsgName = '${vmname}-nsg'

var nsgId = resourceId(resourceGroup().name, 'Microsoft.Network/networkSecurityGroups', nsgName)
var vnetId = resourceId(resourceGroup().name, 'Microsoft.Network/virtualNetworks', 'vnet1')
var subnetRef = '${vnetId}/subnets/sub1'

var vnet1scope = [
  '10.0.0.0/24'
]

var vnet1Subnets = [
  {
    name: 'sub1'
    properties: {
      addressPrefix: '10.0.0.0/25'
    }
  }
  {
    name: 'sub2'
    properties: {
      addressPrefix: '10.0.0.128/25'
    }
  }
]

var vnet2scope = [
  '10.0.0.0/24'
]

var vnet2Subnets = [
  {
    name: 'sub1'
    properties: {
      addressPrefix: '10.0.0.0/25'
    }
  }
  {
    name: 'sub2'
    properties: {
      addressPrefix: '10.0.0.128/25'
    }
  }
]

resource vnet1 'Microsoft.Network/virtualNetworks@2019-09-01' = {
  name: 'vnet1'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: vnet1scope
    }
    subnets: vnet1Subnets
  }
}

resource vnet2 'Microsoft.Network/virtualNetworks@2019-09-01' = {
  name: 'vnet2'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: vnet2scope
    }
    subnets: vnet2Subnets
  }
}

resource hqstorageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageName
  location: resourceGroup().location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
}

resource simplevm_networkcard 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId(resourceGroup().name, 'Microsoft.Network/publicIpAddresses', publicIpName)
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
  dependsOn: [
    simplevm_nsg
    vnet1
    simplevm_ip
  ]
}

resource simplevm_nsg 'Microsoft.Network/networkSecurityGroups@2019-02-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 300
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange:'22'
        }
      }
    ]
  }
}

resource simplevm_ip 'Microsoft.Network/publicIpAddresses@2019-02-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource simplevm 'Microsoft.Compute/virtualMachines@2020-12-01' = {
  name: vmname
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmsize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: simplevm_networkcard.id
        }
      ]
    }
    osProfile: {
      computerName: vmname
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource sql 'Microsoft.Sql/servers@2020-11-01-preview' = {
  name: sqlName
  location: resourceGroup().location
  tags: {}
  properties: {
    administratorLogin: 'DoMyNick'
    administratorLoginPassword: sqlPass
  }
}

