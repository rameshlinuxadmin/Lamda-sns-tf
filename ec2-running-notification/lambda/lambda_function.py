import json
import os
import boto3

sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

def lambda_handler(event, context):
    instance_id = event["detail"]["instance-id"]
    state       = event["detail"]["state"]
    region      = event["region"]
    time        = event["time"]

    message = f"""
EC2 Instance State Change Notification

Instance ID : {instance_id}
State       : {state}
Region      : {region}
Time        : {time}
"""

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="EC2 Instance Started",
        Message=message
    )

    return {
        "statusCode": 200,
        "body": "Notification sent"
    }