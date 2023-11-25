FROM golang:1.20
ENV PORT 8080
EXPOSE 8080

WORKDIR /go/src/app
COPY . .

ARG GO111MODULE=off
RUN go get -d -v ./...
RUN go build -v -o app ./...
RUN mv ./app /go/bin/

CMD ["app"]