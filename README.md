# Traccar on AWS Lambda

This project runs Traccar on AWS Lambda, processing requests and returning responses.

## Environment Variables

The following environment variables are required:

- `S3_BUCKET_NAME`: The name of the S3 bucket where response files will be uploaded.

## Response Handling

This Lambda function handles responses differently based on their size:

### For responses larger than 6MB:
1. Compresses the response data
2. Uploads it to the specified S3 bucket
3. Returns a JSON object with a pre-signed URL to the uploaded file:
   ```json
   {
     "url": "https://your-bucket.s3.amazonaws.com/response-uuid.gz?..."
   }
   ```
   The pre-signed URL is valid for 1 hour by default.

### For responses 6MB or smaller:
1. Compresses the response data
2. Returns the compressed data directly in the response body
3. Sets appropriate headers (Content-Encoding: gzip)

### Status Code and Redirection
The Lambda function always returns a 302 (Found/Redirect) status code regardless of the original response status code from the Traccar server. 

The response includes a `Location` header to facilitate proper HTTP redirection:
- For responses larger than 6MB: The `Location` header points to the S3 URL where the compressed data is stored
- For responses 6MB or smaller: The `Location` header points to the root path (`/`)

## Deployment

Make sure to:
1. Create an S3 bucket for storing the response files
2. Set the `S3_BUCKET_NAME` environment variable in your Lambda function configuration
3. Ensure the Lambda execution role has permissions to write to the specified S3 bucket
