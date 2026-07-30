function machine-create-digitalocean
	set -l project "$SECRET_API_KEY_PROJECT"
	if test -z "$project"
		set project flurdy
	end

	set -l token (secret-api-key lookup digitalocean "$project")
	if test $status -ne 0; or test -z "$token"
		echo "DigitalOcean API key unavailable for project $project" >&2
		return 1
	end

	set -lx DIGITALOCEAN_ACCESS_TOKEN "$token"
	set -e token

	docker-machine create \
		-d digitalocean \
		--digitalocean-size 2gb \
		$argv
end

