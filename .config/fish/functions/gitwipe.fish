function gitwipe
	git add -A
	and git commit -m "TMP: Save before wipe"
	and git reset HEAD~1 --hard 
end
