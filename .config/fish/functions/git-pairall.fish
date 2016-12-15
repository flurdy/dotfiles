function git-pairall
  if test (count $argv) -eq 2 
	 echo "Pairing projects in $PAIR_PROJECT_WORKSPACE"
	 for PROJ in $PAIR_PROJECT_WORKSPACE/*
	   if test -d $PROJ/.git
		  cd $PROJ
		  and git pair $argv
	   end
    end
	 and cd $PAIR_PROJECT_WORKSPACE
  else
    echo "Two in a pair please, not: $argv" 
  end
end

