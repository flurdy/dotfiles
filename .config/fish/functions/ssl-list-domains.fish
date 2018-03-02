function ssl-list-domains
   for i in $argv
      echo | openssl s_client -showcerts -servername $i -connect $i:443 2>/dev/null | openssl x509 -inform pem -noout -text | grep -A 1 "Alternative Name"
   end
end
