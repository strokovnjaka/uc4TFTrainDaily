cd /home/deploy
az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET  --tenant $ARM_TENANT_ID 
terraform init
