#!/bin/bash

docker container stop ep-copilot-metrics-viewer
docker container rm ep-copilot-metrics-viewer_backup && docker rename ep-copilot-metrics-viewer ep-copilot-metrics-viewer_backup
# Docker run, mapping $(pwd)/data on the host to /usr/share/nginx/html/data in the container
docker build -t ep-copilot-metrics-viewer . && docker run -p 8083:80 --env-file ./.env --name ep-copilot-metrics-viewer -d -v $(pwd)/data:/usr/share/nginx/html/data ep-copilot-metrics-viewer
