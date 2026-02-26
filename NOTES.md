Project 2: Resilient Decoupled Order Processor 🚀

Focus: SQS (FIFO), DynamoDB, Spot Instances, Decoupling, and Route 53.

The Scenario

An e-commerce platform experiences highly variable traffic. They need an order-processing backend that guarantees transactions are processed exactly once and in the exact order received. To save money, the backend processing workers should run on highly discounted compute, as the workload is decoupled and can survive interruptions.

Architecture Overview

Decoupling: An Amazon SQS FIFO Queue to receive "orders."

Compute: An Auto Scaling Group (ASG) composed entirely of Spot Instances sitting in a private subnet.

Database: An Amazon DynamoDB table with a Partition Key of OrderID to store the processed results.

DNS: A Route 53 Hosted Zone using a Failover Routing Policy, pointing to your primary region, with a standby static S3 error page in case the whole region goes down.

Implementation Steps

Terraform: Provision the SQS FIFO Queue, the DynamoDB Table, and the Auto Scaling Group configured to request Spot capacity. Provision the Route 53 records and the standby S3 bucket.

Ansible: Write a playbook to configure the Spot instances on boot (you can use EC2 User Data to trigger the Ansible pull or run it locally on the baked AMI). The playbook should deploy a simple Python worker script.

The Python Worker (The App): Write a 30-line Python script (using the boto3 library) that constantly polls the SQS FIFO queue, processes the "order," writes the result to DynamoDB, and then deletes the message from the queue.

AWS CLI (The Test): Use the CLI to rapidly send 100 mock order messages into the SQS FIFO queue and watch your Spot instances process them in exact order.

Why this is a great portfolio piece:

It demonstrates advanced architectural patterns. You are showing you know how to build fault-tolerant systems using Spot Instances (cost optimization), how to decouple tiers with SQS, and when to specifically use FIFO queues vs Standard queues.
