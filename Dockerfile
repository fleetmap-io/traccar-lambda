ARG ARCH=x86_64
FROM public.ecr.aws/lambda/provided:al2023-$ARCH


COPY traccar.xml /opt/traccar/conf/traccar.xml
COPY traccar.run /var/runtime/bootstrap
COPY entrypoint.sh /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap
RUN /var/runtime/bootstrap/traccar.run
CMD [ "function.handler" ]

