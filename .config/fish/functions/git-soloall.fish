function git-soloall
	echo "Going solo in $PAIR_PROJECT_WORKSPACE"
	for PROJ in $PAIR_PROJECT_WORKSPACE/*
	  if test -d $PROJ/.git
	    echo "Going solo for project $PROJ"
	    and cd $PROJ
	    and git solo
	  end
	end
	and cd $PAIR_PROJECT_WORKSPACE
end
