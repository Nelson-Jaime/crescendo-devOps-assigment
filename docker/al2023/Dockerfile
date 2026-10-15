# Amazon Linux 2023 test image for the EC2 user_data script (the real AMI's OS family, same dnf repositories).
# Only the stand-ins listed below are added; the script itself installs nginx, unzip and Java with dnf.
FROM public.ecr.aws/amazonlinux/amazonlinux:2023

# Tools the real AL2023 AMI already ships but the minimal container image does not,
# plus procps/iproute for the assertions. Nothing the script installs itself.
RUN dnf install -y --setopt=install_weak_deps=False tar gzip shadow-utils procps-ng util-linux findutils iproute \
 && dnf clean all

COPY systemctl-stub.sh /usr/local/bin/systemctl
COPY provision.sh /root/provision.sh
RUN chmod +x /usr/local/bin/systemctl /root/provision.sh
