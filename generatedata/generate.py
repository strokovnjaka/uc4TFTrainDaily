from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
import numpy as np
from datetime import datetime
import os
from mailto import mail_results


def data_generator(t, mem_length, b_size):
    """
    Generate data for the copying memory task (from TCN)
    :param t: The total blank time length
    :param mem_length: The length of the memory to be recalled
    :param b_size: The batch size
    :return: Input and target data tensor
    """
    seq = np.array(np.random.randint(1, 9, size=(b_size, mem_length)), dtype=float)
    zeros = np.zeros((b_size, t))
    marker = 9 * np.ones((b_size, mem_length + 1))
    placeholders = np.zeros((b_size, mem_length))

    x = np.array(np.concatenate((seq, zeros[:, :-1], marker), 1), dtype=int)
    y = np.array(np.concatenate((placeholders, zeros, seq), 1), dtype=int)
    return np.expand_dims(x, axis=2).astype(np.float32), np.expand_dims(y, axis=2).astype(np.float32)


filename = 'tempdata.npz'
blob_name = datetime.today().strftime('training-data-%Y%m%d%H%M%S')

message = ""

try:
    print("Getting env...")
    connect_str = os.getenv('ASB_CONNECT_STR')
    container_name = os.getenv('ASB_CONTAINER_NAME')
    print("Generating samples...")
    samples_train = np.random.randint(3000, 5000)
    samples_test = int(samples_train/5)
    x_train, y_train = data_generator(601, 10, samples_train)
    x_test, y_test = data_generator(601, 10, samples_test)
    print("Saving compressed...")
    np.savez_compressed(filename, x_train=x_train, x_test=x_test, y_train=y_train, y_test=y_test)

    print("Getting blob service client...")
    blob_service_client = BlobServiceClient.from_connection_string(connect_str)
    try:
        print("Creating container...")
        blob_service_client.create_container(container_name)
        print("   ...done.")
    except ResourceExistsError:
        print("   ...skipped, container already exists.")

    blob_client = blob_service_client.get_blob_client(container=container_name, blob=blob_name)

    print(f"Uploading blob:\t{blob_name}\t...")
    with open(filename, "rb") as data:
        blob_client.upload_blob(data)
    print("   ...done.")
except Exception as e:
    message = f"the following error occured while getting training data:\n{e}"

print("Results are...")
success = message == ""
if success:
    print("   ...success!")
else:
    print("   ...error:\n{message}")
subject = "New training data available" if success else "Error getting training data"
message = f"new training data has been made available:\n\nSamples: {samples_train}/{samples_test}\nContainer: {container_name}\nBlob: {blob_name}" if success else message
mail_results(subject, message)
print("Done.")
