function kubesecret 
   # echo Extracting Kubernetes secret paramaters
   if test (count $argv) -eq 3
		set SECRET (kubectl get secret -n $argv[3] --template="{{.data.$argv[2]}}" $argv[1])
		echo $SECRET | base64 --decode 
   else if test (count $argv) -eq 2
		set SECRET (kubectl get secret -n apps --template="{{.data.$argv[2]}}" $argv[1])
		echo $SECRET | base64 --decode 
	else
     echo 2 or 3 arguments required
	  echo kubesecret [secret] [parameter] | [namespace]
	end
end
