ARG ARCH=x86_64
FROM public.ecr.aws/lambda/provided:al2023-$ARCH

RUN dnf install -y gzip tar jq

COPY setup/out /opt/traccar
COPY traccar.xml /opt/traccar/conf/traccar.xml
COPY entrypoint.sh /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap

CMD [ "function.handler" ]

