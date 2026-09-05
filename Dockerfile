FROM golang:1.27-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -ldflags='-s -w' -o /server ./cmd/server

FROM alpine:3.23
RUN apk add --no-cache ca-certificates && adduser -D -u 10001 syncraft
COPY --from=build /server /usr/local/bin/server
USER syncraft
ENV LISTEN_ADDR=0.0.0.0:8091
EXPOSE 8091
HEALTHCHECK --interval=15s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1:8091/health/ready || exit 1
ENTRYPOINT ["server"]
