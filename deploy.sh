#!/bin/bash

docker build -t ep-copilot-metrics-viewer . && docker run -p 8083:80 --env-file ./.env ep-copilot-metrics-viewer
