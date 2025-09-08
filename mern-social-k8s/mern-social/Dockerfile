# Dockerfile 
# (use this version of node because that's whats in the mern-social repo)
FROM node:8.11.1

# Create a directory inside the image to hold the app's code
RUN mkdir -p /usr/src/app

# Set that dir as the working dir for all subsequent insrtuctions
WORKDIR /usr/src/app

# Copy only package.json first,
# this way, if dependencies havent changed, Docker can reuse the layer
# And skip reinstalling modules.
COPY package.json /usr/src/app

# Install app dependencies (from package.json)
RUN npm install

# Copy the rest of the application code into the container
COPY . /usr/src/app

# Build the React client bundle (runs "npm run build" defined in pakage.json
# This prepares static files that the Express server can serve.
RUN npm run build

# Expose port 3000 so Kubernetes can map traffic into the container
EXPOSE 3000

# Default command: start the Node.js server
CMD ["npm", "start"]

