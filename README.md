# TerraformInfrastructure
The necessary infrastructure will be set up on AWS using Terraform to host a website.
## Steps

* Configure the necessary credentials to use the AWS CLI, since Terraform uses the AWS CLI underneath.
* Apply Terraform commands.
```
terraform plan
terraform apply 
```


The previous commands create all the necessary infrastructure.
* Sub-net
* VPC
* Aws_route: tabla de rutas
* Security Group
* Instance RDS
* AWS-iam-role
* Instance EC2
* ALB
