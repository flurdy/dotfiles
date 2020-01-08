function kube
   if test ! -z "$KUBECONTEXT"
      echo "Kubernetes context is $KUBECONTEXT"
      kubectl --context $KUBECONTEXT $argv
   else
      set KubeCurrentContext (kubectl config current-context)
      echo "Kubernetes default context is $KubeCurrentContext"
   	kubectl $argv
   end
end
