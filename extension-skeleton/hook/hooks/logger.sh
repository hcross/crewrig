#!/bin/bash
# Hook: ${SKELETON_NAME} logger
# Intercepts tool calls. Modify or validate the payload as needed.

read -r PAYLOAD
echo "$PAYLOAD"
