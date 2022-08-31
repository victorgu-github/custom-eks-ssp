# kubeflow helm chart
- kubeflow community use kustomize and don't provide official helm chart https://github.com/kubeflow/kubeflow/issues/3173
may provide unofficial chart commented sebastien-prudhomme 
- kubeflow 1.5 chart https://github.com/alauda/kubeflow-chart not work on eks 1.21, 2.20!!! 


# kubeflow-pipelines chart https://github.com/getindata/helm-charts/tree/main/charts/kubeflow-pipelines
- kubeflow pipeline only chart https://getindata.com/blog/kubeflow-pipelines-running-5-minutes/  
only works with gcp --version 1.6.2
for aws get error https://github.com/kubeflow/pipelines/issues/4505, same even after installing cert-manager, may cause by latest version
no cert issue on version 1.6.2, but got mysql deploy issue since mysql-sa not created
!!! try aws with RDS, works except s3 access deny. 

- kubeflow pipelines can deploy using yaml https://www.kubeflow.org/docs/components/pipelines/installation/standalone-deployment/#deploying-kubeflow-pipelines  same cert error like above
export PIPELINE_VERSION=1.6.0 works with error Could not resolve host: metadata.google.internal