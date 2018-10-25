cat <<EOF | tee /etc/ssh/sshd_config
Port 22
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AllowAgentForwarding yes
AllowTcpForwarding yes
GatewayPorts no
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem       sftp    /usr/lib/openssh/sftp-server
EOF

mkdir -p /root/.ssh
cat <<EOF | tee /root/.ssh/authorized_keys
#admins
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJIilfi4A7YYN4brYWMx8PLU7ddpNno1ZlAlFjGyAKSRu27mf5wHAYzQxsHxNVxFoEzkUeV9BdPpqLuHfYYjYgLVx9KzvNKGwWmgVN0Y71Ak3gwGJZ/FZRk0yz6oxN01rhyfhxcCVo2kTsGo6YA4nEUERLjUaikkjzxcDhWVauS3AQL3i2N/DWoeiFfQ7shp5VGiPpm3naAu6uaMA2Y2B5jl1kb+wjqElgN8HjsGKdyfNcdsGUKMwjNHq//fXfEXPSd+rNqcztdMrOoE2jeGpaYYKCbkGCCQF2PTrsr9bMO6LT7tbfNgfcjAyAO7kRnzXLOoek2qi4ntD80FLg/OEj timofeev@timofeev
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVzkowKz6geiG++xe0W2mwNU88xw7yJlLDgW9stgdnnSlm7rm5bCIYRvxJAiu0IaFr78sR7BvJA+f8xf1YvMwRQjKXUf+38WygODeDi1tA6K/i1IedZS50ocGUCAF7mnk202x1nYVeQR0MHCFS29l+twpDYDlIrc2WOIHiim7yehwFCI3aa7GMQZDOMtdJF9tfiNIlOFCAuoGbvPUFXYz1p0wH0U7xnIDsNP+lLTdanPG++/6CEfDyoJADUmfQVLOqtmhgs/qMhnI4ZB0LA8D2k2js/TWYJE78Q0siWzBzQ1KWyNYFmIm0EP6dBqy6i5NI4EKSNwOXCHZhod3E25sv artemov@DESKTOP-76E9RB6
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDHb5JrpEfYPzU82k4Km1hLfK2NNbKVnfzZgCBFdvwVsg/2hI1ryXZd1pth4j/oaYmAhtUZFm/LlxRxcqc2J4eI1i/P2HTkJtTXtkI9Osx6zR7uRUrESOphwCZl6sJyqwuDmaUdEYl2sZPFVhQaTZ7tyMKawxNNh1LPUuhSFWmUT2pAFA4C5NOzt2SOfF4tZMN3lbXlJwQ5l94+7Q8SoI2kP1NtkneqSeHIUSaUcuDSESnqm/NW7Z8qZzy/40u20JVhzmRaLXEzXvIf/i7zVhRfkSf19fwYaCgNTdg8SEuIJDk5nUzoNY6bGcGPorzRq+GiVBsNuZqTLJjZFkebR2BC6k/YHRGLRHRbbLEJQrmHtv6JDFfYhQ9mdnQrjulm7/DfwdFmuQfbGMkvizKgAIHCfkXjcTvNug4hfqbmCT972P/B2cTp0N+rtpzsTkyEoXvdBrjKDLmNkwOfmoEGLpD9hCYYaye3dRnO9oYEsC7REKTxPyyNoE+0KbHyNvXSQIroBIwK2qUdjN0BYDkd1IqUrWM+j2wmjBp4bQ/mK76aCnI+1WseXSqjxjj6B/RY82Oaf63q1n1xAVCuwBfFd6hGG/YVE9mYNINkorIFbpu4LUrZukc1C9EoBFQyr9ohKaRN/DfSkLpdQ/1Cf6gvUaPG67d44VXetjzpoc+BsKI+fw== jeff@9debian
EOF
chmod 0400 /root/.ssh