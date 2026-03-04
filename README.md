# Serverless Image Processing Pipeline

## Project Overview
This project implements a serverless image processing pipeline on Google Cloud using Terraform.

## Architecture
1. Client uploads an image using API Gateway
2. API Gateway triggers the upload-image Cloud Function
3. A message is published to Pub/Sub
4. process-image function processes the image
5. The processed image is stored in Cloud Storage
6. log-notification function logs the processing result

## Technologies Used

- Google Cloud Storage
- Pub/Sub
- Cloud Functions (Gen2)
- Secret Manager
- API Gateway
- Terraform

## Deployment Steps

```bash
terraform init
```
```bash
terraform apply
```
## API Endpoint

### POST
```
/v1/images/upload
```
### Region
```
us-central1
```
### Project ID
```
project-8175b238-5b8b-4fa4-8cf
```

---

# Final Project Structure

Your folder should now look like:
```
serverless-image-pipeline
│
├── main.tf
├── variables.tf
├── outputs.tf
├── submission.json
├── README.md
│
├── api
│ └── openapi.yaml
│
└── functions
├── upload-image
│ ├── main.py
│ └── requirements.txt
│
├── process-image
│ ├── main.py
│ └── requirements.txt
│
└── log-notification
├── main.py
└── requirements.txt
```
---