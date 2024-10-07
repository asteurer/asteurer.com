ARG GOLANG_VER=1.23
FROM golang:${GOLANG_VER}-alpine as builder
WORKDIR /app
COPY ./go .

# - vips-dev: Development files for libvips
# - build-base: Basic build tools (includes gcc, make, etc.)
# - pkgconf: pkg-config implementation for Alpine
RUN apk add --no-cache vips-dev build-base pkgconf
RUN go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -o main main.go

FROM alpine
# Install libvips runtime dependency
RUN apk add --no-cache vips
COPY --from=builder /app/main main
RUN chmod +x main
CMD ["./main"]