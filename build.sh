docker build -t traccar-lambda .
docker tag traccar-lambda:latest 533267349510.dkr.ecr.us-east-1.amazonaws.com/traccar-lambda
docker push 533267349510.dkr.ecr.us-east-1.amazonaws.com/traccar-lambda
