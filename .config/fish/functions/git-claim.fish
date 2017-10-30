function git-claim
   echo Setting git email to $GIT_MY_EMAIL
	git config user.email $GIT_MY_EMAIL
	and git config user.name "$GIT_MY_NAME"
end
