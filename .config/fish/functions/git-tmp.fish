function git-tmp
	git saveall
	and set branchnow (git symbolic-ref --short HEAD)
	and set datenow (date -u +"%Y%m%d-%H%M%S")
	and git branch "tmp/$branchnow-$datenow"
	and git undo
end
