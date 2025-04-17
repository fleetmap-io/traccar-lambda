ARG ARCH=x86_64
FROM public.ecr.aws/lambda/java:21-$ARCH

COPY traccar.xml /var/task/traccar.xml
COPY build/classes/java/main ${LAMBDA_TASK_ROOT}
COPY build/deps ${LAMBDA_TASK_ROOT}/lib

CMD ["Handler::handleRequest"]
