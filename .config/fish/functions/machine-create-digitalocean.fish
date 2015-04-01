function machine-create-digitalocean 
	docker-machine create \
	-d digitalocean \
	--digitalocean-access-token $DIGITALOCEAN_ACCESS_TOKEN \
	--digitalocean-size 2gb \
	$argv
end

