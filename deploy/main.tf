# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "uc4storageaccount"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix}ContainerRegistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Build docker image and push it to acr
resource "null_resource" "build_generate_app" {
  depends_on = [
    azurerm_container_registry.acr,
  ]
  provisioner "local-exec" {
    # TODO: docker login not secure:
    #     WARNING! Using --password via the CLI is insecure. Use --password-stdin.
    #     WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
    #     Configure a credential helper to remove this warning. See
    #     https://docs.docker.com/engine/reference/commandline/login/#credentials-store
    command = <<EOT
      docker login ${azurerm_container_registry.acr.login_server} --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET &&
      docker build --file Dockerfile --tag=${var.app_name_generatedata} --build-arg ASB_CONNECT_STR="${azurerm_storage_account.storage_account.primary_connection_string}" --build-arg ASB_CONTAINER_NAME="${var.container_name}" . &&
      docker tag ${var.app_name_generatedata} ${azurerm_container_registry.acr.login_server}/${var.app_name_generatedata} &&
      docker push ${azurerm_container_registry.acr.login_server}/${var.app_name_generatedata}
    EOT
    working_dir = "/home/generatedata"
  }
}

# Build docker image and push it to acr
resource "null_resource" "build_app" {
  depends_on = [
    azurerm_container_registry.acr,
  ]
  provisioner "local-exec" {
    # TODO: docker login not secure:
    #     WARNING! Using --password via the CLI is insecure. Use --password-stdin.
    #     WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
    #     Configure a credential helper to remove this warning. See
    #     https://docs.docker.com/engine/reference/commandline/login/#credentials-store
    command = <<EOT
      docker login ${azurerm_container_registry.acr.login_server} --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET &&
      docker build --file Dockerfile --tag=${var.app_name_tftrain} --build-arg ASB_CONNECT_STR="${azurerm_storage_account.storage_account.primary_connection_string}" --build-arg ASB_CONTAINER_NAME="${var.container_name}" --build-arg ASB_MODEL_CONTAINER_NAME="${var.model_container_name}" . &&
      docker tag ${var.app_name_tftrain} ${azurerm_container_registry.acr.login_server}/${var.app_name_tftrain} &&
      docker push ${azurerm_container_registry.acr.login_server}/${var.app_name_tftrain}
    EOT
    working_dir = "/home/tftrain"
  }
}

# Create the generate container and group
resource "azurerm_container_group" "acg" {
  depends_on = [
    null_resource.build_app,
  ]
  name                = "${var.prefix}-acg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  restart_policy      = "Never"
  os_type             = "Linux"

  container {
    name   = var.app_name_generatedata
    image  = "${azurerm_container_registry.acr.login_server}/${var.app_name_generatedata}:latest"
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 443
      protocol = "TCP"
    }
  }
  image_registry_credential {
    server = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    # TODO: use Vault to retrieve the password
    password = azurerm_container_registry.acr.admin_password
  }
}

# Create the train container and group
resource "azurerm_container_group" "acgtrain" {
  depends_on = [
    null_resource.build_app,
  ]
  name                = "${var.prefix}-acgtrain"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  restart_policy      = "Never"
  os_type             = "Linux"

  container {
    name   = var.app_name_tftrain
    image  = "${azurerm_container_registry.acr.login_server}/${var.app_name_tftrain}:latest"
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 444
      protocol = "TCP"
    }
  }
  image_registry_credential {
    server = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    # TODO: use Vault to retrieve the password
    password = azurerm_container_registry.acr.admin_password
  }
}

# Deploy the workflow with ARM template 
resource "azurerm_resource_group_template_deployment" "workflow" {
  depends_on = [
    azurerm_container_group.acg,
  ]

  name                = "${var.prefix}-wf-design"
  resource_group_name = azurerm_resource_group.main.name
  deployment_mode = "Incremental"

  parameters_content  = jsonencode({
    "connections_aci_name" = {
      value = "aci"
    },
    "connections_api_name" = {
      value = "aci"
    },
    "workflow_name" = {
      value = "${var.prefix}-logicapp"
    },
    "client_id" = {
      value = "${var.client_id}"
    },
    "client_secret" = {
      value = "${var.client_secret}"
    },
    "acg_name" = {
      value = azurerm_container_group.acg.name
    }
  })

  template_content    = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "connections_aci_name": {
            "type": "string"
        },
        "connections_api_name": {
            "type": "string"
        },
        "client_id": {
            "type": "string"
        },
        "client_secret": {
            "type": "securestring"
        },
        "workflow_name": {
            "type": "string"
         },
         "acg_name": {
            "type": "string"
         }
    },
    "functions": [],
    "variables": {},
    "resources": [
        {
            "name": "[parameters('connections_aci_name')]",
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "location": "[resourceGroup().location]",
            "tags": {},
            "properties": {
                "displayName": "[parameters('connections_aci_name')]",
                "parameterValues": {
                    "token:clientId": "[parameters('client_id')]",
                    "token:clientSecret": "[parameters('client_secret')]",
                    "token:TenantId": "[subscription().tenantId]",
                    "token:grantType": "client_credentials"
                },
                "customParameterValues": {},
                "nonSecretParameterValues": {},
                "api": {
                    "id": "[concat(subscription().id, '/providers/Microsoft.Web/locations/', resourceGroup().location, '/managedApis/', parameters('connections_api_name'))]"
                }
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "[parameters('workflow_name')]",
            "location": "westeurope",
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Day",
                                "interval": 1,
                                "schedule": {
                                    "hours": [
                                        "0"
                                    ],
                                    "minutes": [
                                        27
                                    ]
                                }
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Day",
                                "interval": 1,
                                "schedule": {
                                    "hours": [
                                        "0"
                                    ],
                                    "minutes": [
                                        27
                                    ]
                                }
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Start_containers_in_a_container_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['aci']['connectionId']"
                                    }
                                },
                                "method": "post",
                                "path": "[concat(subscription().id, '/resourceGroups/', resourceGroup().name, '/providers/Microsoft.ContainerInstance/containerGroups/', parameters('acg_name'), '/start')]",
                                "queries": {
                                    "x-ms-api-version": "2019-12-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "aci": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', parameters('connections_aci_name'))]",
                                "connectionName": "[parameters('connections_aci_name')]",
                                "id": "[reference(concat('Microsoft.Web/connections/', parameters('connections_aci_name')), '2016-06-01').api.id]"
                            }
                        }
                    }
                }
            },
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', parameters('connections_aci_name'))]"
            ]
        }
    ],
    "outputs": {}
}
  TEMPLATE
}
