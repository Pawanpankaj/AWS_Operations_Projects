# AWS_Operations_Projects

# 1. Check which all the services running on your Account across All the regions.



    for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do echo "===== $r ====="; echo -n "EC2 Instances: "; aws ec2 describe-instances --region "$r" --query 'Reservations[].Instances[].InstanceId' --output text | wc -w; echo -n "VPCs: "; aws ec2 describe-vpcs --region "$r" --query 'Vpcs[].VpcId' --output text | wc -w; echo -n "Subnets: "; aws ec2 describe-subnets --region "$r" --query 'Subnets[].SubnetId' --output text | wc -w; echo -n "RDS: "; aws rds describe-db-instances --region "$r" --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null | wc -w; echo -n "Lambda: "; aws lambda list-functions --region "$r" --query 'Functions[].FunctionName' --output text 2>/dev/null | wc -w; echo -n "EKS: "; aws eks list-clusters --region "$r" --query 'clusters[]' --output text 2>/dev/null | wc -w; echo -n "DynamoDB: "; aws dynamodb list-tables --region "$r" --query 'TableNames[]' --output text 2>/dev/null | wc -w; echo; done
    

