function aws
	command docker run --rm -it -v ~/.aws:/root/.aws -v (pwd):/aws amazon/aws-cli $argv
end
