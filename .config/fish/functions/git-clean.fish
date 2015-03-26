function git-clean
	git add -A
	and git commit -m "TMP: Save before clean reset"
	and git reset HEAD~1 --hard 
end
