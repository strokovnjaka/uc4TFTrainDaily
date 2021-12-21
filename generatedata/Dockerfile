FROM python:latest
LABEL maintainer strokovnjaka

ARG ASB_CONNECT_STR
ARG ASB_CONTAINER_NAME
ENV ASB_CONNECT_STR=$ASB_CONNECT_STR
ENV ASB_CONTAINER_NAME=$ASB_CONTAINER_NAME

RUN pip install numpy azure-storage-blob

COPY generate.py /home
COPY mailto.py /home

CMD python3 /home/generate.py