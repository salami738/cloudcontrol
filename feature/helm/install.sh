. /feature-installer-utils.sh

TEMPDIR=$(mktemp -d)
cd "${TEMPDIR}" || exit

execHandle "Downloading helm" curl -f -s "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" --output helm.tar.gz
execHandle "Unpacking helm" tar xzf helm.tar.gz
execHandle "Installing helm" mv linux-amd64/helm /home/cloudcontrol/bin

if [ -r /tiller ]
then
  execHandle "Installing tiller" mv linux-amd64/tiller /home/cloudcontrol/bin
fi

cd - &>/dev/null || exit
rm -rf "${TEMPDIR}"
