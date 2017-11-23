# Etherpad docker image

Adapted version of etherpad-lite for OAE.

## Usage

### Run from dockerhub

```
docker run -it --name=etherpad --net=host oaeproject/oae-etherpad-docker
```

### Build the image locally

```
# Step 1: Build the image
docker build -f Dockerfile -t oae-etherpad:latest .
# Step 2: Run the container
docker run -it --name=etherpad --net=host oae-etherpad:latest
```
