1. install gatekeeper with helm at https://open-policy-agent.github.io/gatekeeper/website/docs/install#deploying-via-helm
!!! workshop install is out of date https://www.eksworkshop.com/intermediate/310_opa_gatekeeper/setup/

2. apply req-anno-template.yaml and lb-constraint.yaml, it requires loadbacler service with  annotation

3. gatekeeper was able to replace PSP (deparecated!) with its psp library 
https://aws.amazon.com/blogs/containers/using-gatekeeper-as-a-drop-in-pod-security-policy-replacement-in-amazon-eks/