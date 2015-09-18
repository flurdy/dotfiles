function git-pairall
	and for PROJ in $PAIR_PROJECTS
	  echo "Pairing project $PROJ"
	  and cd $PAIR_PROJECT_WORKSPACE/$PROJ
	  and git pair $argv
	end
	and cd $PAIR_PROJECT_WORKSPACE
end
