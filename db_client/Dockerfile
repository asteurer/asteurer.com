ARG GOLANG_VER=1.23
FROM golang:${GOLANG_VER}-alpine AS builder
WORKDIR /app
COPY ./go .
RUN go mod download
RUN go build -o main main.go

FROM scratch
COPY --from=builder /app/main main
CMD ["./main"]