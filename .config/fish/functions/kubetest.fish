function kubetest
  command kubectl --kubeconfig=$KUBE_CONFIG_TEST $argv
end

