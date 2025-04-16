ARG ARCH=x86_64
FROM public.ecr.aws/lambda/provided:al2023-$ARCH


COPY traccar.xml /opt/traccar/conf/traccar.xml
COPY traccar.run /opt/traccar/traccar.run
COPY entrypoint.sh /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap /opt/traccar/traccar.run
RUN /opt/traccar/traccar.run

CMD [ "function.handler" ]

