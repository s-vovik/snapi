import boto3
from botocore.exceptions import ClientError
import os

ec2_client = boto3.client("ec2")

print('Loading function')

def lambda_handler(event, context):
    print(os.environ["EC2_INSTANCE"])
    responses = ec2_client.start_instances(
        InstanceIds=[
            os.environ["EC2_INSTANCE"]
        ]
    )

    return {
        "statusCode": 200,
    }