# test liveness app
kubectl exec -it liveness-app -- /bin/kill -s SIGUSR1 1
wait for 20s and will see pod restart 


# test readiness app
kubectl exec -it <YOUR-READINESS-POD-NAME> -- rm /tmp/healthy