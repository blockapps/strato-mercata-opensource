# What is EKS
Amazon Elastic Kubernetes Service (Amazon EKS) is a managed service that we can use to run Kubernetes on AWS without needing to install, operate, and maintain our own Kubernetes control panel. More detailed information can be found [here](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)

# Installing kubectl
Follow steps from [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html)

# Update kubectl with the EKS cluster
* *aws eks update-kubeconfig --name ba-dev3 --region us-east-1*

# Execute the run script
cd k8s/eks/strato
./run.sh
