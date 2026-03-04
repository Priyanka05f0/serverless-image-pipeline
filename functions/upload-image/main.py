import functions_framework
from google.cloud import storage
from google.cloud import pubsub_v1
import uuid

PROJECT_ID = "project-8175b238-5b8b-4fa4-8cf"
BUCKET_NAME = "project-8175b238-5b8b-4fa4-8cf-uploads"
TOPIC_ID = "image-processing-requests"

@functions_framework.http
def upload_image(request):

    if request.method != "POST":
        return ("Only POST allowed", 405)

    if 'file' not in request.files:
        return ("No file uploaded", 400)

    file = request.files['file']
    filename = str(uuid.uuid4()) + "-" + file.filename

    storage_client = storage.Client()
    bucket = storage_client.bucket(BUCKET_NAME)
    blob = bucket.blob(filename)

    blob.upload_from_file(file)

    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

    message = f"{BUCKET_NAME}/{filename}"
    publisher.publish(topic_path, message.encode("utf-8"))

    return ("Upload accepted", 202)