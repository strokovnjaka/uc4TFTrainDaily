# Use case training a tcn model

The example is to show how to trigger ML training based on new data being available.

Setup two docker images, one for getting new data (random samples generated in this case), another for training the model with new data. The generating one is triggered by a logic app little after midnight, the training one is triggered via azure functions blob trigger.

## Build the image

First, by editing [mailto/mailto.tmpl.py](./mailto/mailto.tmpl.py) create `mailto.py` to enable mailing capabilities, so the two containers can mail messages and results.

You can also prepare the credentials (see below) before building the image, so they are ready when running. Note that in this case you should treat the image as private.

```bash
docker build --file Dockerfile --tag=strokovnjaka/uc4tftrain .
```


## Test the image

### Run container

Prepare `credentials/azure.env` (e.g. from the template file `credentials/azure.env.tmpl`). Note that in this case you should treat the container as private.

Run the container:

```bash
docker run -d --privileged --rm --env-file "credentials/azure.env" --name uc4tftrain strokovnjaka/uc4tftrain
```

### Step into container

```bash
docker exec -it uc4tftrain /bin/bash
```


### Run terraform in container

As terraform is initialized via `.bashrc`, just apply the plan:

```bash
terraform apply
```

This creates the Azure Container Registry, then the two docker images (generate, train) to be pushed to ACR. Next, an Azure Logic App is created that schedules running the data generator container daily at defined time.

What is also needed is creating azure function that uses blob trigger. For that do:
- resource create -> function app
    - resource group is `ucTFTrain-resources`
    - name is `ucTFTtrain-funcapp`
    - stack is `Powershell core`
    - region is e.g. `west europe`
- edit funcapp App files
    - copy `host.json`, `profile.ps1`, `requirements.psd1` from `aftriggerps/` dir
- edit funcapp configuration
    - new app setting named `AzureWebJobsStorage`, copy value from storage setting (not sure why this isn't setup by the portal)
    - new app setting `SubscriptionId`, copy from env
- turn on funcapp identity System assigned
    - add role assignment -> Resource group -> select custom role that you setup for the app
- create function, copy `run.ps1` from `aftriggerps/BlobTrigger1/` dir

NOTE: for some reason, ACI (Azure Client Instances) kill running containers at random (see [this](https://docs.microsoft.com/en-us/answers/questions/281794/azure-container-instance-killed-for-no-reason-afte.html) or [this](https://josefbajada.medium.com/8-reasons-why-azure-container-instances-suck-a8a81fa91f92)). Due to this ACI buggyness, the above steps are describing manual azure portal manipulation. If it worked, that would have been implemented as template deployment (similar to logic app deployment)


## Push the image to Docker Hub

In case you want to push the image to the hub:

```bash
docker push strokovnjaka/uc4tftrain
```