# Use official Node.js LTS image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (none needed, but good practice)
RUN npm install --production || true

# Copy application files
COPY . .

# Expose port
EXPOSE 8080

# Set environment variable for port
ENV PORT=8080

# Start the application
CMD ["node", "server.js"]
