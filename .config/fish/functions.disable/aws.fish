function aws
	command docker run --rm -i -v ~/.aws:/root/.aws -v (pwd):/aws amazon/aws-cli $argv
end
