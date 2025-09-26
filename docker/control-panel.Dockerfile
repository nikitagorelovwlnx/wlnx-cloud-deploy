# Control Panel Dockerfile for Google Cloud Run
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies and live-server globally
RUN npm install && npm install -g live-server && npm cache clean --force

# Copy source code
COPY . .

# Build the TypeScript application
RUN npm run build

# Remove dev dependencies
RUN npm prune --production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start application
CMD ["npm", "start"]
