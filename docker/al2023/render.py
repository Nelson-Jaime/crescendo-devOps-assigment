#!/usr/bin/env python3
"""Render infra/modules/compute/templates/provision.sh.tpl the way Terraform's templatefile() does.

It reads the same inputs main.tf passes (the files in modules/compute/files/ and the defaults in
infra/variables.tf), so the script under test is the user_data script a real `terraform apply` would
send to EC2. Terraform escapes are honoured: "$${" -> "${" and "%%{" -> "%{". Substitution is a single
pass, so "${...}" inside inserted files (for example Tomcat's ${catalina.base}) is left untouched.

Usage: render.py <output-file>
Environment overrides: INSTANCE_TYPE (public|author), EXPOSE_ADMIN (true|false), JVM_HEAP_MB.
"""
import os
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
COMPUTE = ROOT / "infra" / "modules" / "compute"
VARIABLES_TF = ROOT / "infra" / "variables.tf"


def die(message):
    sys.exit(f"render.py: {message}")


def tf_default(name):
    """Default of a root variable, parsed from variables.tf (strings and numbers/bools only)."""
    text = VARIABLES_TF.read_text()
    block = re.search(r'variable\s+"%s"\s*\{(.*?)\n\}' % re.escape(name), text, re.S)
    if not block:
        die(f"variable {name} not found in {VARIABLES_TF}")
    default = re.search(r"^\s*default\s*=\s*(.+?)\s*$", block.group(1), re.M)
    if not default:
        die(f"variable {name} has no default")
    value = default.group(1)
    return value[1:-1] if value.startswith('"') and value.endswith('"') else value


def read(name):
    return (COMPUTE / "files" / name).read_text().rstrip("\n")


def build_values():
    instance_type = os.environ.get("INSTANCE_TYPE") or tf_default("magnolia_instance_type")
    expose_admin = (os.environ.get("EXPOSE_ADMIN") or tf_default("expose_admin")) == "true"
    return {
        "tomcat_version": tf_default("tomcat_version"),
        "java_package": tf_default("java_package"),
        "magnolia_war_url": tf_default("magnolia_war_url"),
        "heap_mb": os.environ.get("JVM_HEAP_MB") or tf_default("jvm_heap_mb"),
        "author_instance": "true" if instance_type == "author" else "false",
        "nginx_conf": read("nginx.conf"),
        "nginx_admin_conf": read("nginx-admin-open.conf" if expose_admin else "nginx-admin-blocked.conf"),
        "server_xml": read("server.xml"),
        "tomcat_unit": read("tomcat.service"),
        "magnolia_properties": read("magnolia-overrides.properties"),
    }


TOKEN = re.compile(r"\$\$\{|%%\{|\$\{(\w+)\}|(?<!%)%\{")


def render(template, values):
    # Terraform would reject a "${" that is not a plain variable reference, or a "%{" directive.
    stripped = template.replace("$${", "")
    bad = re.search(r"\$\{(?!\w+\})", stripped)
    if bad:
        die("template contains an unescaped ${ that is not a variable reference (write $${ in the template)")

    def substitute(match):
        token = match.group(0)
        if token == "$${":
            return "${"
        if token == "%%{":
            return "%{"
        if token.startswith("%{"):
            die("template contains an unescaped %{ directive (write %%{ in the template)")
        name = match.group(1)
        if name not in values:
            die(f"template references ${{{name}}} but main.tf-equivalent values do not define it")
        return str(values[name])

    return TOKEN.sub(substitute, template)


def main():
    if len(sys.argv) != 2:
        die("usage: render.py <output-file>")
    template = (COMPUTE / "templates" / "provision.sh.tpl").read_text()
    pathlib.Path(sys.argv[1]).write_text(render(template, build_values()))


if __name__ == "__main__":
    main()
