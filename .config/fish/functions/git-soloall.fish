function git-soloall
	and for PROJ in $PAIR_PROJECTS
	  echo "Going solo for project $PROJ"
	  and cd $PAIR_PROJECT_WORKSPACE/$PROJ
	  and git solo
	end
	and cd $PAIR_PROJECT_WORKSPACE
end
