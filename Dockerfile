# ==========================================
# Production-Ready Lean Non-Root Dockerfile
# ==========================================

# Use official Alpine-based Node.js runtime for minimal footprint and reduced attack surface
FROM node:20-alpine AS base

# Install dumb-init or wget if needed (wget is included in Alpine)
RUN apk --no-cache add dumb-init

# Set production environment variables
ENV NODE_ENV=production \
    PORT=3000

# Set working directory
WORKDIR /usr/src/app

# Copy dependency manifests first to leverage Docker layer caching
COPY package.json ./

# Install dependencies (only production packages)
RUN npm install --omit=dev --ignore-scripts && \
    npm cache clean --force

# Copy application source code
COPY --chown=node:node server.js ./

# Assign directory ownership to unprivileged non-root user 'node' (UID/GID 1000)
RUN chown -R node:node /usr/src/app

# Switch to non-root user for principle of least privilege
USER node

# Expose internal microservice listening port
EXPOSE 3000

# Add container-level HEALTHCHECK instruction
HEALTHCHECK --interval=20s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Launch application via dumb-init for proper PID 1 signal forwarding (SIGTERM / SIGINT)
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "server.js"]
