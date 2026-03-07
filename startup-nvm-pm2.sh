#!/bin/bash

# Startup script for CentOS 7.9 to set nvm Node.js version and start pm2

# Load nvm (adjust path if nvm is installed in a different location)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Use Node.js 14.21.3
nvm use 14.21.3

# Start pm2 with the specified JavaScript file
# Replace 'your-app.js' with your actual JavaScript file name
pm2 start your-app.js

# Save pm2 process list
pm2 save