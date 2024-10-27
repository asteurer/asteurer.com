import sys
import yaml
import os

def main():
    # Check that environment variables have been properly set
    ip_addr = os.environ.get('IP_ADDR')
    domain = os.environ.get('DOMAIN')
    env_errors = []
    if not ip_addr:
        env_errors.append("Environment variable 'IP_ADDR' is not set.")
    if not domain:
        env_errors.append("Environment variable 'DOMAIN' is not set.")
    if len(env_errors) > 0:
        print("\n".join(env_errors), file=sys.stderr)
        sys.exit(1)

    # Read YAML data from stdin
    try:
        data = yaml.safe_load(sys.stdin)
    except yaml.YAMLError as exc:
        print(f"Error parsing YAML input: {exc}", file=sys.stderr)
        sys.exit(1)

    # Update the KUBECONFIG fields to ensure they are unique
    for cluster_entry in data['clusters']:
        cluster_entry['cluster']['server'] = f'https://{ip_addr}:6443'
        cluster_entry['name'] = domain

    for context_entry in data['contexts']:
        context_entry['context']['cluster'] = domain
        context_entry['context']['user'] = domain + '_user'
        context_entry['name'] = domain

    data['current-context'] = domain

    for user_entry in data['users']:
        user_entry['name'] = domain + '_user'

    # Write updated YAML to stdout
    try:
        yaml.dump(data, sys.stdout, default_flow_style=False)
    except yaml.YAMLError as exc:
        print(f"Error writing YAML output: {exc}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
