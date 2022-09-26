# install
kubectl create ns splunk
kubectl -n splunk run splunk  --image=splunk/splunk:latest --env=SPLUNK_START_ARGS=--accept-license --env=SPLUNK_PASSWORD=Splunk@123456
kubectl expose pod splunk --port=8000 --name=splunk-admin -n splunk
kubectl -n splunk port-forward service/splunk-admin 8000:8000 // 8080:8000 first is your local port 

# config 
http://localhost:8000
Login with admin/Splunk@123456
Go to settings →indexes
Create two new index(ex:journal & kube) for events with default.
Go to settings →Data inputs →HTTP Event Collector
Create two New Token →Specify name of token(ex:journal and kube) →Next →Select Allowed Index →Review →Submit
Get your token values and replace it in the following definition as Splunk_Token
Go to settings →Data inputs →HTTP Event Collector
Go to Global setting,make sure it is enabled.Check the port number.Default is 8088.
Create a service for HTTP Event Collector based on HTTP Port Number in Global Setting

kubectl expose pod splunk --port=8088 --name=splunk-hec -n splunk


# search
Go to App:Search & Reporting
Datasets tab-> create table view -> select index