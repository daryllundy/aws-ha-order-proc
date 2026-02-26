#!/usr/bin/env python3
import json, os, time
import boto3
from botocore.exceptions import ClientError

region = os.getenv("AWS_REGION", "us-east-1")
queue_url = os.environ["QUEUE_URL"]
table_name = os.environ["DDB_TABLE"]
sqs = boto3.client("sqs", region_name=region)
ddb = boto3.resource("dynamodb", region_name=region).Table(table_name)

def process_order(payload):
    return {"status": "processed", "total": payload.get("total", 0), "ts": int(time.time())}

while True:
    resp = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1, WaitTimeSeconds=20)
    for msg in resp.get("Messages", []):
        body = json.loads(msg["Body"])
        oid = body["order_id"]
        try:
            ddb.put_item(
                Item={"OrderID": oid, "Result": json.dumps(process_order(body)), "Raw": json.dumps(body)},
                ConditionExpression="attribute_not_exists(OrderID)",
            )
            print(f"processed {oid}", flush=True)
        except ClientError as e:
            if e.response["Error"]["Code"] != "ConditionalCheckFailedException":
                raise
        sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg["ReceiptHandle"])
