function gitrebaseclean
	git reset --hard 
	and git checkout master 
	and git rebase --abort
end
