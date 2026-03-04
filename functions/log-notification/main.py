import base64
import json
import logging
import functions_framework


@functions_framework.cloud_event
def log_notification(cloud_event):

    message_data = base64.b64decode(
        cloud_event.data["message"]["data"]
    ).decode()

    data = json.loads(message_data)

    original_file = data.get("original_file")
    processed_file = data.get("processed_file")

    logging.info(
        f"Image processed successfully | Original: {original_file} | Processed: {processed_file}"
    )