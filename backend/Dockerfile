# Multi-stage Dockerfile for Backhaul Logistics Backend
# Supports both development and production builds

# ============================================
# Base stage - common dependencies
# ============================================
FROM node:20-alpine AS base

WORKDIR /app

# Install system dependencies for native modules
RUN apk add --no-cache python3 make g++ bash

# Copy package files first for better caching
COPY package*.json ./

# ============================================
# Dependencies stage - install all dependencies
# ============================================
FROM base AS dependencies

RUN npm ci --only=production && npm cache clean --force

# ============================================
# Development stage - for local development
# ============================================
FROM base AS development

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies)
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Start application in watch mode
CMD ["npm", "run", "start:dev"]

# ============================================
# Build stage - compile TypeScript
# ============================================
FROM base AS build

WORKDIR /app

# Copy package files and install all dependencies
COPY package*.json ./
RUN npm ci

# Copy source code and configuration
COPY tsconfig*.json ./
COPY nest-cli.json ./
COPY src ./src

# Build the application
RUN npm run build

# Clean up dev dependencies
RUN npm prune --production

# ============================================
# Production stage - minimal runtime image
# ============================================
FROM node:20-alpine AS production

WORKDIR /app

# Install only necessary system dependencies (for bcrypt native module)
RUN apk add --no-cache tini

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

# Copy built application from build stage
COPY --from=build --chown=nextjs:nodejs /app/dist ./dist
COPY --from=build --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=build --chown=nextjs:nodejs /app/package.json ./package.json

# Copy environment file (will be overridden by docker-compose)
COPY --chown=nextjs:nodejs .env .env

# Switch to non-root user
USER nextjs

# Expose port
EXPOSE 3000

# Use tini for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# Start the application
CMD ["node", "dist/main.js"]