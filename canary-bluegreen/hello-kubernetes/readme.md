sample application for deployment

 helm install  v1 \
  ./hello-kubernetes \
  --set message="You are reaching hello-kubernetes version 1" \
  --set ingress.configured=true \
  --set service.type="ClusterIP"
  
   helm install  v2 \
  ./hello-kubernetes \
  --set message="You are reaching hello-kubernetes version 2" \
  --set ingress.configured=true \
  --set service.type="ClusterIP"