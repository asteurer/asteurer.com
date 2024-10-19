ARG GOLANG_VER=1.23
FROM golang:${GOLANG_VER}-alpine AS builder
# Install build dependencies for bimg library
RUN apk add --no-cache vips-dev build-base pkgconf
WORKDIR /app
COPY ./go .
RUN go mod download
RUN go build -o main main.go

FROM alpine:3.20
# Install runtime dependencies for bimg library
RUN apk add --no-cache vips
COPY --from=builder /app/main main
RUN chmod +x main
CMD ["./main"]