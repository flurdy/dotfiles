function flatrun 
#	/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=gitkraken --file-forwarding com.axosoft.GitKraken @@u %U @@ $argv
  /usr/bin/flatpak run --branch=stable --arch=x86_64 --command=$argv[1] --file-forwarding $argv[2] @@u %U @@ $argv[3..-1] 
end

