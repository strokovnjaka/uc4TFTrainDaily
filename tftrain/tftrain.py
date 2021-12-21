from azure.storage.blob import BlobServiceClient, ContainerClient
from azure.core.exceptions import ResourceExistsError
from tcn import compiled_tcn
import tensorflow as tf
import numpy as np
import smtplib
import ssl
from datetime import datetime
import os
from operator import attrgetter
import shutil
from mailto import mail_results


filename = 'tempdata.npz'
filename_model = 'tempmodel'
dirname_model = 'tempmodeldir'
blob_name = datetime.today().strftime('model-%Y%m%d%H%M%S.zip')

epochs = 2

mail_results("Starting training", f"training of model with new data for {epochs} epochs is starting now.")

message = ""

try:
    print("Getting env...")
    connect_str = os.getenv('ASB_CONNECT_STR')
    container_name = os.getenv('ASB_CONTAINER_NAME')
    model_container_name = os.getenv('ASB_MODEL_CONTAINER_NAME')

    print("Getting container client...")
    container = ContainerClient.from_connection_string(conn_str=connect_str, container_name=container_name)

    print("Listing blobs...")
    blob_list = container.list_blobs()
    print("Finding last blob...")
    last_blob = max(blob_list, key=attrgetter('last_modified'))
    print(f"Training on {last_blob.name} from {last_blob.last_modified}")
    print("Getting blob...")
    blob = container.get_blob_client(last_blob)
    with open(filename, "wb") as npfile:
        blob_data = blob.download_blob()
        blob_data.readinto(npfile)
    print(f"Downloaded to {filename}")

    print(f"Loading to data...")
    npzdata = np.load(filename)
    x_train = npzdata['x_train']
    x_test = npzdata['x_test']
    y_train = npzdata['y_train']
    y_test = npzdata['y_test']

    print(f"Creating model...")
    model = compiled_tcn(num_feat=1,
                         num_classes=10,
                         nb_filters=10,
                         kernel_size=8,
                         dilations=[2 ** i for i in range(9)],
                         nb_stacks=1,
                         max_len=x_train[0:1].shape[1],
                         use_skip_connections=True,
                         opt='rmsprop',
                         lr=5e-4,
                         use_weight_norm=True,
                         return_sequences=True)

    # Using sparse softmax.
    # http://chappers.github.io/web%20micro%20log/2017/01/26/quick-models-in-keras/
    print(f"Training model...")
    model.fit(x_train, y_train, validation_data=(x_test, y_test), epochs=epochs, batch_size=256)
    print(f"Evaluating model...")
    test_acc = model.evaluate(x=x_test, y=y_test)[1]  # accuracy.
    print(f"Saving model...")
    model.save(dirname_model)
    print("Zipping model...")
    shutil.make_archive(filename_model, 'zip', dirname_model)

    blob_service_client = BlobServiceClient.from_connection_string(connect_str)
    print("Creating model container...")
    try:
        blob_service_client.create_container(model_container_name)
        print(f"   ...created {model_container_name}.")
    except ResourceExistsError:
        print("   ...skipped, {model_container_name} already exists.")

    blob_client = blob_service_client.get_blob_client(container=model_container_name, blob=blob_name)

    print(f"Uploading model blob {blob_name}...")
    with open(filename_model+".zip", "rb") as data:
        blob_client.upload_blob(data)
except Exception as e:
    message = f"the following error occured while training:\n{e}"


print("Results are...")
success = message == ""
if success:
    print("   ...success!")
else:
    print("   ...error:\n{message}")
subject = "New model available" if success else "Error training model"
message = f"new model has been made available:\n\nTest accuracy: {test_acc}\nTraining from: {container_name}/{last_blob.name}\nModel saved to: {model_container_name}/{blob_name} " if success else message
mail_results(subject, message)
print("Done.")
