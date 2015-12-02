function git-pairall
  if test -d $argv
    echo "No pairs chosen" 
  else
	 for PROJ in $PAIR_PROJECTS
	   echo "Pairing project $PROJ"
	   and cd $PAIR_PROJECT_WORKSPACE/$PROJ
	   and git pair $argv
	   and cd $PAIR_PROJECT_WORKSPACE
		end
	end
end
