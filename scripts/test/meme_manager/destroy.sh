#!/bin/bash

# Exporting for Terraform
export AWS_ACCESS_KEY_ID=$(op item get aws_asteurer_temp --fields label=access_key --reveal)
export AWS_SECRET_ACCESS_KEY=$(op item get aws_asteurer_temp --fields label=secret_access_key --reveal)
export AWS_SESSION_TOKEN=$(op item get aws_asteurer_temp --fields label=session_token --reveal)

region=us-west-2
bucket_name=asteurer.com-dev

terraform -chdir=scripts/test/meme_manager destroy \
  --var=aws_region=$region \
  --var=bucket_name=$bucket_name \
  --auto-approve

sudo docker stop $(sudo docker ps | awk '/website-test/ {print $1}')