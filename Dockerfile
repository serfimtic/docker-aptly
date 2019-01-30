FROM golang:latest

RUN apt update && apt install -y bzip2 xz-utils gnupg gpgv libc6

RUN go get github.com/smira/aptly

COPY miscellaneous/aptly.conf /etc/aptly.conf

VOLUME ["/aptly"]

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT [ "docker-entrypoint.sh" ]

EXPOSE 8080

CMD ["aptly serve"]