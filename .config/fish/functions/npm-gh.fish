function npm-gh --description 'Run npm with GitHub Packages auth from the keyring'
	set -l project "$NPM_TOKEN_PROJECT"
	if test -z "$project"
		set project "$SECRET_API_KEY_PROJECT"
	end
	if test -z "$project"
		set project flurdy
	end

	set -l token (secret-api-key lookup github "$project")
	if test $status -ne 0; or test -z "$token"
		echo "npm registry token unavailable for project $project" >&2
		return 1
	end

	set -lx NPM_TOKEN "$token"
	set -e token

	command npm $argv
end
