# oae-etherpad

Adapted version of etherpad-lite integrated in OAE project

## Usage
```
# Step 1: Build the image
docker build -f Dockerfile -t oae-etherpad:latest .
# Step 2: Run the container
docker run -it --name=etherpad --net=host oae-etherpad:latest
```
