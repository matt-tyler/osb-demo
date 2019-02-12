# STEP 1 build executable binary

FROM golang:1.11-alpine AS build_base

# Install git
RUN apk update && apk add git && apk add ca-certificates

WORKDIR /go/src/github.com/matt-tyler/osb-demo

ENV GO111MODULE=on

# Create appuser
RUN adduser -D -g '' appuser

COPY go.mod .
COPY go.sum .

RUN go mod download

FROM build_base AS builder

COPY . .

#build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -ldflags '-w -s' -o /go/bin/osb-demo

# STEP 2 build a small image

# start from scratch
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /etc/passwd /etc/passwd
# Copy our static executable
COPY --from=builder /go/bin/osb-demo /go/bin/osb-demo
USER appuser

ENTRYPOINT ["/go/bin/osb-demo"]