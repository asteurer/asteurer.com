FROM node:22.14 AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

FROM nginx:1.27-alpine3.21

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy built Svelte assets from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# TODO: Create custom nginx file
COPY nginx/nginx.conf /etc/nginx/conf.d

EXPOSE 80 443