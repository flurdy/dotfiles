function git-ditch
	git add -A
	and git commit -m "TMP: Save before ditch reset"
	and git reset HEAD~1 --hard 
end
