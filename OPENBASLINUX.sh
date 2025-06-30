#!/bin/sh
set -e

base_url=http://10.0.3.10:8080
architecture=$(uname -m)

os=$(uname | tr '[:upper:]' '[:lower:]')
install_dir="$HOME/.local/openbas-agent-session"
session_name="openbas-agent-session"

if [ "${os}" != "linux" ]; then
  echo "Operating system $OSTYPE is not supported yet, please create a ticket in openbas github project"
  exit 1
fi

if ! systemctl is-system-running >/dev/null 2>&1; then
  echo "Linux detected but systemd is not running. This installation is not supported."
  exit 1
fi

echo "Starting install script for ${os} | ${architecture}"

echo "01. Stopping existing ${session_name}..."
systemctl --user stop ${session_name} || echo "Fail stopping ${session_name}"

echo "02. Downloading OpenBAS Agent into ${install_dir}..."
(mkdir -p ${install_dir} && touch ${install_dir} >/dev/null 2>&1) || (echo -n "\nFatal: Can't write to ${install_dir}\n" >&2 && exit 1)
curl -sSfL ${base_url}/api/agent/executable/openbas/${os}/${architecture} -o ${install_dir}/openbas-agent
chmod +x ${install_dir}/openbas-agent

echo "03. Creating OpenBAS configuration file"
cat > ${install_dir}/openbas-agent-config.toml <<EOF
debug=false

[openbas]
url = "http://localhost:8080"
token = "135c853c-8ab2-4323-95b8-4258d444201c"
unsecured_certificate = "false"
with_proxy = "false"
installation_mode = "session-user"
EOF

echo "04. Writing agent service"
cat > ${install_dir}/${session_name}.service <<EOF
[Unit]
Description=OpenBAS Agent Session
After=network.target
[Service]
Type=exec
ExecStart=${install_dir}/openbas-agent
StandardOutput=journal
[Install]
WantedBy=default.target
EOF

echo "05. Starting agent service"
(
  ln -sf ${install_dir}/${session_name}.service $HOME/.config/systemd/user/
  systemctl --user daemon-reload
  systemctl --user enable ${session_name}
  systemctl --user start ${session_name}
) || (echo "Error while enabling OpenBAS Agent systemd unit file or starting the agent" >&2 && exit 1)

echo "OpenBAS Agent started."
