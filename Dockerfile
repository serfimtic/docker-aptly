FROM golang:latest

RUN go get github.com/smira/aptly

ADD aptly.conf /etc/aptly.conf
VOLUME ["/aptly"]
