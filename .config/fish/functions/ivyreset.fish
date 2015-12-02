function ivyreset 
	rm -f ~/.sbt/boot/sbt.boot.lock
	and rm -f ~/.ivy2/.sbt.cache.lock
	and rm -f ~/.ivy2/.sbt.ivy.lock
end
