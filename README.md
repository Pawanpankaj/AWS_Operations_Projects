# AWS_Operations_Projects

# 1. Check which all the services running on your Account across All the regions.



    for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do echo "===== $r ====="; echo -n "EC2 Instances: "; aws ec2 describe-instances --region "$r" --query 'Reservations[].Instances[].InstanceId' --output text | wc -w; echo -n "VPCs: "; aws ec2 describe-vpcs --region "$r" --query 'Vpcs[].VpcId' --output text | wc -w; echo -n "Subnets: "; aws ec2 describe-subnets --region "$r" --query 'Subnets[].SubnetId' --output text | wc -w; echo -n "RDS: "; aws rds describe-db-instances --region "$r" --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null | wc -w; echo -n "Lambda: "; aws lambda list-functions --region "$r" --query 'Functions[].FunctionName' --output text 2>/dev/null | wc -w; echo -n "EKS: "; aws eks list-clusters --region "$r" --query 'clusters[]' --output text 2>/dev/null | wc -w; echo -n "DynamoDB: "; aws dynamodb list-tables --region "$r" --query 'TableNames[]' --output text 2>/dev/null | wc -w; echo; done
    
# 2. delete default vpc .

@'
# delete_default_vpc_all_regions.ps1
# Fixed: describe-regions now anchored to us-east-1

$accountId = (aws sts get-caller-identity --query Account --output text)
Write-Host "=============================================="
Write-Host " Account ID : $accountId"
Write-Host "=============================================="

$confirm = Read-Host "Delete DEFAULT VPCs in ALL regions of account $accountId ? Type yes to continue"
if ($confirm -ne "yes") {
 Write-Host "Aborted by user."
 exit 0
}

# FIX: anchor describe-regions to a region so it can run
$regions = (aws ec2 describe-regions --region us-east-1 --all-regions --query "Regions[?OptInStatus!='not-opted-in'].RegionName" --output text) -split "\s+"

if ($regions.Count -eq 0 -or $regions[0] -eq "") {
 Write-Host "Could not retrieve regions. Check your permissions." -ForegroundColor Red
 exit 1
}

Write-Host "Regions to process: $($regions -join ', ')"
$results = @()

foreach ($Region in $regions) {
 if ($Region -eq "") { continue }
 Write-Host ""
 Write-Host "=========== Region: $Region ==========="

 $vpcId = (aws ec2 describe-vpcs --region $Region --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)

 if ($vpcId -eq "None" -or $vpcId -eq "") {
 Write-Host "No default VPC found. Skipping."
 $results += [pscustomobject]@{ Region=$Region; VpcId="-"; Status="No default VPC" }
 continue
 }
 Write-Host "Found default VPC: $vpcId"

 $igwId = (aws ec2 describe-internet-gateways --region $Region --filters Name=attachment.vpc-id,Values=$vpcId --query "InternetGateways[0].InternetGatewayId" --output text)
 if ($igwId -ne "None" -and $igwId -ne "") {
 Write-Host "Detaching and deleting IGW: $igwId"
 aws ec2 detach-internet-gateway --region $Region --internet-gateway-id $igwId --vpc-id $vpcId 2>&1 | Out-Host
 aws ec2 delete-internet-gateway --region $Region --internet-gateway-id $igwId 2>&1 | Out-Host
 }

 $subnets = (aws ec2 describe-subnets --region $Region --filters Name=vpc-id,Values=$vpcId --query "Subnets[].SubnetId" --output text)
 foreach ($subnet in ($subnets -split "\s+")) {
 if ($subnet -ne "" -and $subnet -ne "None") {
 Write-Host "Deleting subnet: $subnet"
 aws ec2 delete-subnet --region $Region --subnet-id $subnet 2>&1 | Out-Host
 }
 }

 Write-Host "Deleting default VPC: $vpcId"
 $deleteOutput = (aws ec2 delete-vpc --region $Region --vpc-id $vpcId 2>&1)
 if ($LASTEXITCODE -eq 0) {
 Write-Host "SUCCESS: Deleted $vpcId in $Region" -ForegroundColor Green
 $results += [pscustomobject]@{ Region=$Region; VpcId=$vpcId; Status="Deleted" }
 } else {
 Write-Host "FAILED to delete $vpcId in $Region" -ForegroundColor Red
 Write-Host "Reason: $deleteOutput" -ForegroundColor Yellow
 $results += [pscustomobject]@{ Region=$Region; VpcId=$vpcId; Status="FAILED: $deleteOutput" }
 }
}

Write-Host ""
Write-Host "==================== SUMMARY ===================="
$results | Format-Table -AutoSize -Wrap
Write-Host "All regions processed. Done."
'@ | Out-File -FilePath ".\delete_default_vpc_all_regions.ps1" -Encoding utf8 -Force
