import functions_framework
from google.cloud import pubsub_v1
import json
import os

# Initialize outside to reuse, but handle the Project ID safely
publisher = pubsub_v1.PublisherClient()
TOPIC_ID = "image-processing-requests"

@functions_framework.cloud_event
def upload_image(cloud_event):
    # Move Project ID check inside or provide a hardcoded fallback
    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT") or "project-8175b238-5b8b-4fa4-8cf"
    
    try:
        data = cloud_event.data
        # Eventarc for GCS sometimes nests data or uses 'name' vs 'file'
        bucket = data.get("bucket")
        name = data.get("name")

        if not name or not bucket:
            print(f"Skipping: Missing data. Bucket: {bucket}, Name: {name}")
            return

        if name.endswith(".zip"):
            print(f"Skipping source code zip: {name}")
            return

        topic_path = publisher.topic_path(project_id, TOPIC_ID)
        message = json.dumps({"bucket": bucket, "name": name}).encode("utf-8")

        future = publisher.publish(topic_path, message)
        print(f"SUCCESS: Published {name} to Pub/Sub. ID: {future.result()}")

    except Exception as e:
        print(f"CRITICAL ERROR in upload_image: {e}")