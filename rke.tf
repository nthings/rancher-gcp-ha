resource "null_resource" "rke" {
  provisioner "local-exec" {
    command = "echo \"${templatefile("templates/rke.tmpl", {
      ips              = google_compute_instance.rke.*.network_interface.0.access_config.0.nat_ip,
      private_ips      = google_compute_instance.rke.*.network_interface.0.network_ip,
      user             = "demo",
      private_key_path = "~/keys/aws_terraform"
    })}\" > cluster.yml"
  }

  provisioner "local-exec" {
    command = <<EOT
rke up --config cluster.yml;
export KUBECONFIG=kube_config_cluster.yml;
kubectl -n kube-system create serviceaccount tiller;
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller;
helm init --service-account tiller;
kubectl rollout status -w deployment/tiller-deploy --namespace=kube-system;
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable;
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml;
kubectl create namespace cert-manager;
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true;
helm repo add jetstack https://charts.jetstack.io;
helm repo update;
helm install --name cert-manager --namespace cert-manager --version v0.9.1 jetstack/cert-manager;
kubectl rollout status -w deployment/cert-manager --namespace=cert-manager;
helm install rancher-stable/rancher --name rancher --namespace cattle-system --set hostname=rancher.nthin.gs --set ingress.tls.source=letsEncrypt --set letsEncrypt.email=webmaster@rancher.nthin.gs;
    EOT
  }

  depends_on = ["google_compute_instance.rke"]
}

resource "null_resource" "remove_files" {
  provisioner "local-exec" {
    command = <<EOT
rm -f kube_config_cluster.yml;
rm -f cluster.yml;
rm -f cluster.rkestate;
    EOT
    when    = "destroy"
  }
}