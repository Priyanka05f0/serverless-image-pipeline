import base64
import json
import functions_framework
from google.cloud import storage
from google.cloud import pubsub_v1
from PIL import Image
import io

PROJECT_ID = "project-8175b238-5b8b-4fa4-8cf"
UPLOAD_BUCKET = "project-8175b238-5b8b-4fa4-8cf-uploads"
PROCESSED_BUCKET = "project-8175b238-5b8b-4fa4-8cf-processed"
RESULT_TOPIC = "image-processing-results"


@functions_framework.cloud_event
def process_image(cloud_event):

    message_data = base64.b64decode(
        cloud_event.data["message"]["data"]
    ).decode()

    data = json.loads(message_data)

    file_name = data["file_name"]

    storage_client = storage.Client()

    upload_bucket = storage_client.bucket(UPLOAD_BUCKET)
    processed_bucket = storage_client.bucket(PROCESSED_BUCKET)

    blob = upload_bucket.blob(file_name)

    image_bytes = blob.download_as_bytes()

    image = Image.open(io.BytesIO(image_bytes))

    grayscale_image = image.convert("L")

    output_buffer = io.BytesIO()

    grayscale_image.save(output_buffer, format="PNG")

    processed_blob = processed_bucket.blob(file_name)

    processed_blob.upload_from_string(output_buffer.getvalue())

    publisher = pubsub_v1.PublisherClient()

    topic_path = publisher.topic_path(PROJECT_ID, RESULT_TOPIC)

    result_message = json.dumps({
        "original_file": file_name,
        "processed_file": file_name
    })

    publisher.publish(
        topic_path,
        result_message.encode("utf-8")
    )