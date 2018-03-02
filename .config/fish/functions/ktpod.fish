function ktpod 
   ktpods $argv | egrep "^$argv" | awk '{print $1}' | head -n 1
end
