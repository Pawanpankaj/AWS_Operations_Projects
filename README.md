# AWS_Operations_Projects

# 1. Check which all the services running on your Account across All the regions.



    for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do echo "===== $r ====="; echo -n "EC2 Instances: "; aws ec2 describe-instances --region "$r" --query 'Reservations[].Instances[].InstanceId' --output text | wc -w; echo -n "VPCs: "; aws ec2 describe-vpcs --region "$r" --query 'Vpcs[].VpcId' --output text | wc -w; echo -n "Subnets: "; aws ec2 describe-subnets --region "$r" --query 'Subnets[].SubnetId' --output text | wc -w; echo -n "RDS: "; aws rds describe-db-instances --region "$r" --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null | wc -w; echo -n "Lambda: "; aws lambda list-functions --region "$r" --query 'Functions[].FunctionName' --output text 2>/dev/null | wc -w; echo -n "EKS: "; aws eks list-clusters --region "$r" --query 'clusters[]' --output text 2>/dev/null | wc -w; echo -n "DynamoDB: "; aws dynamodb list-tables --region "$r" --query 'TableNames[]' --output text 2>/dev/null | wc -w; echo; done
    
# 2. delete default vpc .

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

