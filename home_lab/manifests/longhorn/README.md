Excellent, that error message is very specific and tells us exactly what's wrong.

This error means that Longhorn's manager pod checked your Kubernetes nodes (the virtual machines on Proxmox) and found that the open-iscsi package is missing. Longhorn requires this package on all cluster nodes to manage the attachment of its storage volumes to your pods using the iSCSI protocol.

The Solution
You need to SSH into each of your Kubernetes nodes (control-plane and worker nodes) and install the open-iscsi client package.

Here are the commands based on the Linux distribution you are using for your Kubernetes node VMs:

For Debian / Ubuntu based systems:
This is the most common for Proxmox VMs.

SSH into your Kubernetes node:
Bash

ssh user@your-k8s-node-ip
Update your package list and install the package:
Bash

sudo apt-get update
sudo apt-get install open-iscsi -y
Ensure the service is enabled and started:
Bash

sudo systemctl enable open-iscsi
sudo systemctl start open-iscsi

Installing Longhorn
You can typically install Longhorn with a single kubectl command.

Add the Longhorn Helm repository:

Bash

helm repo add longhorn https://charts.longhorn.io
helm repo update
Install Longhorn using Helm:

Bash

helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
This command will deploy all the necessary components for Longhorn into its own namespace.

Verify the installation:

Bash

kubectl get pods --namespace longhorn-system
Wait for all the pods to be in the Running state.

3. Creating and Using the StorageClass
Once Longhorn is installed, it automatically creates a default StorageClass for you.

Check for the StorageClass:
You can see the available StorageClasses by running:

Bash

kubectl get storageclass
You should see a longhorn StorageClass listed, which is now ready to be used by your applications.

Using the StorageClass in a PersistentVolumeClaim (PVC):
Now, when you deploy an application that requires persistent storage, you can create a PersistentVolumeClaim that references the longhorn StorageClass.

Here is an example PVC definition:

YAML

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn # This tells Kubernetes to use Longhorn