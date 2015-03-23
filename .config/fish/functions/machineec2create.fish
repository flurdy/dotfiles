function machineec2create 
	docker-machine create \
	-d amazonec2 \
	--amazonec2-access-key $AWS_DOCKER_ACCESS_KEY \
	--amazonec2-secret-key $AWS_DOCKER_SECRET_KEY \
	--amazonec2-vpc-id $AWS_DOCKER_VPC_ID \
	--amazonec2-subnet-id $AWS_DOCKER_SUBNET_ID \
	--amazonec2-region $AWS_DOCKER_REGION \
	--amazonec2-zone $AWS_DOCKER_ZONE \
	--amazonec2-instance-type $AWS_DOCKER_INSTANCE_TYPE \
	$argv
end

