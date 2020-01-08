function recent 
  if test (count $argv) -eq 0 
    echo "Usage: recent [searchterm]"
  else
     history -p -n 10 search $argv | head -n 10
  end 
end
