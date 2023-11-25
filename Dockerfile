FROM golang
RUN mkdir /app
ADD ./get.go /app
WORKDIR /app
EXPOSE 8080
RUN go build -o main ./get.go
CMD ["/app/main"]
