ARG ARCH=x86_64
FROM public.ecr.aws/lambda/provided:al2023-$ARCH

RUN dnf install -y unzip java-17-amazon-corretto jq

RUN curl -L -o /tmp/traccar.zip https://github.com/traccar/traccar/releases/download/v6.6/traccar-other-6.6.zip && \
    mkdir -p /opt/traccar && \
    unzip /tmp/traccar.zip -d /opt/traccar

COPY traccar.xml /opt/traccar/conf/traccar.xml

COPY entrypoint.sh /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap
CMD [ "function.handler" ]

