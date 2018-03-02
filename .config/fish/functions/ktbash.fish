function ktbash
   set pod (ktpod $argv)
   kubetest exec -it $pod bash
end
