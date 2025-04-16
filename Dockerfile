ARG ARCH=x86_64
FROM public.ecr.aws/lambda/provided:al2023-$ARCH


COPY entrypoint.sh /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap
CMD [ "function.handler" ]

#RUN yum install -y unzip bash java-17-amazon-corretto

# Download and extract Traccar
#RUN curl -L -o /tmp/traccar.zip https://github.com/traccar/traccar/releases/download/v6.6/traccar-other-6.6.zip && \
#    mkdir -p /opt/traccar && \
#    unzip /tmp/traccar.zip -d /opt/traccar

# Add your config
#COPY traccar.xml /opt/traccar/conf/traccar.xml

