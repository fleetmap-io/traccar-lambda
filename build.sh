docker build --platform linux/amd64 -t traccar-lambda .
aws ecr get-login-password --profile entrack | docker login --username AWS --password-stdin 533267349510.dkr.ecr.us-east-1.amazonaws.com
docker tag traccar-lambda:latest 533267349510.dkr.ecr.us-east-1.amazonaws.com/traccar-lambda
docker push 533267349510.dkr.ecr.us-east-1.amazonaws.com/traccar-lambda
aws lambda update-function-code \
  --function-name traccar-lambda \
  --image-uri 533267349510.dkr.ecr.us-east-1.amazonaws.com/traccar-lambda:latest \
  --profile entrack \
  --no-cli-pager
echo "waiting..."
aws lambda wait function-updated \
  --function-name traccar-lambda \
  --profile entrack
