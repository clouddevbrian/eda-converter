import json
import boto3

def lambda_handler(event, context):
    mediaconvert = boto3.client('mediaconvert')
    mediaconvert_endpoint = mediaconvert.describe_endpoints(MaxResults=1)
    mediaconvert = boto3.client('mediaconvert', endpoint_url=f"{mediaconvert_endpoint['Endpoints'][0]['Url']}")
    for message in event['Records']:
				# REPLACE ME #
        destination_bucket = 'cattube-destination1912'
				##############
        source_bucket = message['s3']['bucket']['name']
        object = message['s3']['object']['key']
        accountid = context.invoked_function_arn.split(":")[4]
        region = context.invoked_function_arn.split(":")[3]

        with open("job.json", "r") as jsonfile:
            job_config = json.load(jsonfile)

        job_config['Queue'] = f"arn:aws:mediaconvert:{region}:{accountid}:queues/catqueue"
        job_config['Role'] = f"arn:aws:iam::{accountid}:role/MediaConvert_Default_Role"
        job_config['Settings']['Inputs'][0]['FileInput'] = f"s3://{source_bucket}/{object}"
        job_config['Settings']['OutputGroups'][0]['OutputGroupSettings']['FileGroupSettings']['Destination'] = f"s3://{destination_bucket}/"

        response = mediaconvert.create_job(**job_config)