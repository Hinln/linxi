# Base image
FROM node:20-alpine AS builder

# Install OpenSSL (required for Prisma)
RUN apk add --no-cache openssl

# Create app directory
WORKDIR /app

# A wildcard is used to ensure both package.json AND package-lock.json are copied
COPY package*.json ./
COPY prisma ./prisma/

# Install app dependencies
RUN npm install

# Bundle app source
COPY . .

# Generate Prisma Client
RUN npx prisma generate

# Build the app
RUN npm run build

# Production image
FROM node:20-alpine

# Install OpenSSL (required for Prisma)
RUN apk add --no-cache openssl

WORKDIR /app

# Ensure we have all dependencies (including production deps)
# 1. 拷贝编译后的代码产物
COPY --from=builder /app/dist ./dist
# 2. 拷贝生成的 Prisma 客户端 (运行必不可少)
# 我们直接拷贝整个 node_modules 最安全，或者精确拷贝
COPY --from=builder /app/node_modules ./node_modules
# 3. 拷贝 package.json
COPY --from=builder /app/package*.json ./
# 4. 拷贝 prisma 目录 (以便迁移等操作)
COPY --from=builder /app/prisma ./prisma

# Add this to verify dist exists during build
RUN ls -R ./dist

# Expose the port the app runs on
EXPOSE 3000

# Command to run the app
CMD [  "npm", "run", "start:prod" ]
