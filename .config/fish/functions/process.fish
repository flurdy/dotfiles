function process
	ps axf o pid,user,group,comm | grep $argv
end
