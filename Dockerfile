FROM compneurobilbaolab/compneuro-dwiproc:1.0.0

RUN echo "Done pulling compneuro-dwiproc base image"

WORKDIR /app
COPY . /app