# Serverless Image Processing Pipeline on Google Cloud

This project implements a **serverless image processing pipeline** on Google Cloud using **Terraform**.  
It demonstrates an event-driven architecture where uploaded images are processed automatically using Cloud Functions and Pub/Sub.

The infrastructure and services are fully provisioned using **Infrastructure as Code (Terraform)**.

---

# Architecture Overview

The pipeline uses the following Google Cloud services:

- **Cloud Storage** – Stores uploaded and processed images
- **Pub/Sub** – Handles asynchronous messaging between services
- **Cloud Functions (Gen2)** – Performs upload handling, image processing, and logging
- **Secret Manager** – Stores the API key securely
- **API Gateway** – Provides a secure HTTP endpoint for image uploads
- **Terraform** – Manages infrastructure deployment

---

# Workflow

1. A client sends a request to the **API Gateway endpoint**.
2. The request triggers the **upload-image Cloud Function**.
3. The image is uploaded to the **uploads GCS bucket**.
4. A message is published to the **image-processing-requests Pub/Sub topic**.
5. The **process-image Cloud Function** processes the image (grayscale transformation).
6. The processed image is stored in the **processed bucket**.
7. A message is sent to **image-processing-results topic**.
8. The **log-notification Cloud Function** logs the processing completion.

---

# Project Structure
```
serverless-image-pipeline
│
├── terraform/
│ ├── main.tf
│ ├── variables.tf
│ └── outputs.tf
│
├── functions/
│ ├── upload-image/
│ │ ├── main.py
│ │ └── requirements.txt
│ │
│ ├── process-image/
│ │ ├── main.py
│ │ └── requirements.txt
│ │
│ └── log-notification/
│ ├── main.py
│ └── requirements.txt
│
├── api/
│ └── openapi.yaml
│
├── submission.json
├── README.md
└── .gitignore
```

---


# Prerequisites

Before deploying the infrastructure, ensure the following tools are installed:

- **Terraform**
- **Google Cloud SDK (gcloud)**
- **Git**
- **Python 3.11**

You must also have:

- A **Google Cloud project**
- Billing enabled
- Authentication configured

Authenticate using:

```bash
gcloud auth application-default login
```
## Setup Instructions
Clone the repository:
```bash
git clone https://github.com/<your-username>/serverless-image-pipeline.git
cd serverless-image-pipeline
```
Navigate to the Terraform directory:
```bash
cd terraform
```
Initialize Terraform:
```bash
terraform init
```
## Deployment Instructions
To deploy the infrastructure and services:
```bash
terraform apply
```
Terraform will provision:
- Cloud Storage buckets
- Pub/Sub topics
- Cloud Functions
- Secret Manager secrets
- API Gateway
- IAM roles and permissions

Confirm the deployment when prompted:
Enter a value: yes
Deployment may take a few minutes.

## API Endpoint

After deployment, the API Gateway provides an endpoint to upload images.

Example endpoint:
```
https://image-upload-gateway-xxxx.uc.gateway.dev/v1/images/upload
```
The API requires an API key stored in Secret Manager.

## Testing the API

Example request using curl:
```
curl -X POST \
https://image-upload-gateway-xxxx.uc.gateway.dev/v1/images/upload \
-H "x-api-key: dummy-api-key" \
-F "file=@sample.jpg"
```

## Cleanup Instructions

To destroy all resources created by Terraform:
```bash
terraform destroy
```
Confirm the operation when prompted:
Enter a value: yes

This will remove:
- Cloud Functions
- Storage buckets
- Pub/Sub topics
- API Gateway
- Secrets
- IAM configurations

## Security Considerations
- API keys are stored securely in Google Secret Manager
- IAM roles follow the least privilege principle
- API Gateway enforces rate limiting

---
