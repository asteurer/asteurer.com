FROM node:22.14-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
RUN npm install --save-dev @sveltejs/adapter-node
COPY . .
RUN npm run build

FROM node:22.14-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --prod
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./package.json

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080

CMD [ "node", "build" ]