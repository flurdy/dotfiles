function git-eject
	git reset --hard 
	and git checkout master 
	and git rebase --abort
end
