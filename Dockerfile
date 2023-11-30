# syntax=docker/dockerfile:1

FROM golang:1.20

# Set destination for COPY
WORKDIR /app

# Download Go module
COPY go.mod ./

RUN go mod download
RUN go mod verify

# Copy the source code from current local directory
COPY *.go ./

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o /hello-nitro

# Configurable TCP port
ENV PORT=8080

# Run
CMD ["/hello-nitro"]