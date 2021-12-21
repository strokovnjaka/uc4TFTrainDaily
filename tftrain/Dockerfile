FROM tensorflow/tensorflow:latest
LABEL maintainer strokovnjaka

RUN apt-get update 
RUN apt-get install -y git nano

RUN python -m pip install --upgrade pip
RUN python -m pip install tensorflow-addons azure-storage-blob

# install keras-tcn from source, no dependencies
RUN cd /home && git clone https://github.com/strokovnjaka/keras-tcn.git
RUN cd /home/keras-tcn && python3 -m pip install --no-deps .

ARG ASB_CONNECT_STR
ARG ASB_CONTAINER_NAME
ARG ASB_MODEL_CONTAINER_NAME
ENV ASB_CONNECT_STR=$ASB_CONNECT_STR
ENV ASB_CONTAINER_NAME=$ASB_CONTAINER_NAME
ENV ASB_MODEL_CONTAINER_NAME=$ASB_MODEL_CONTAINER_NAME

COPY tftrain.py /home
COPY mailto.py /home

CMD python /home/tftrain.py
