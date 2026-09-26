#!/bin/bash

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=============================================="
echo "Account ID : $ACCOUNT_ID"
echo "=============================================="

for REGION in $(aws ec2 describe-regions \
    --region us-east-1 \
    --query "Regions[?OptInStatus!='not-opted-in'].RegionName" \
    --output text); do

    echo "Processing Region: $REGION"

    VPC_ID=$(aws ec2 describe-vpcs \
        --region $REGION \
        --filters Name=isDefault,Values=true \
        --query "Vpcs[0].VpcId" \
        --output text)

    if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
        echo "No Default VPC found in $REGION"
        continue
    fi

    echo "Default VPC Found: $VPC_ID"

    # Delete Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --region $REGION \
        --filters Name=attachment.vpc-id,Values=$VPC_ID \
        --query "InternetGateways[0].InternetGatewayId" \
        --output text)

    if [[ "$IGW_ID" != "None" && -n "$IGW_ID" ]]; then
        aws ec2 detach-internet-gateway \
            --region $REGION \
            --internet-gateway-id $IGW_ID \
            --vpc-id $VPC_ID

        aws ec2 delete-internet-gateway \
            --region $REGION \
            --internet-gateway-id $IGW_ID
    fi

    # Delete Subnets
    for SUBNET in $(aws ec2 describe-subnets \
        --region $REGION \
        --filters Name=vpc-id,Values=$VPC_ID \
        --query "Subnets[].SubnetId" \
        --output text); do

        aws ec2 delete-subnet \
            --region $REGION \
            --subnet-id $SUBNET
    done

    # Delete VPC
    aws ec2 delete-vpc \
        --region $REGION \
        --vpc-id $VPC_ID

    echo "Deleted Default VPC $VPC_ID in $REGION"

done

echo "Completed."

