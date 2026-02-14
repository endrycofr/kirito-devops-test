# # Stage 1: Build
FROM golang:1.23 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o kirito main.go

# Stage 2: Run
FROM alpine:latest

WORKDIR /app/
COPY --from=builder /app/kirito .

EXPOSE 8080
CMD ["./kirito"]


# =============================================================

# FROM golang:1.23 AS builder
# WORKDIR /app
# COPY . .
# RUN CGO_ENABLED=0 GOOS=linux go build -o kirito main.go

#versi empty base image
# FROM scratch
# WORKDIR /app
# COPY --from=builder /app/kirito .
# EXPOSE 8080
# CMD ["./kirito"]
