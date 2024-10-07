# Overview

This is the source code for [asteurer.com](https://asteurer.com).

## Diagram

Below is a visual overview of the site's backend:

![asteurer.com diagram](README_files/asteurer.com_diagram.png)

## Technologies Used

### Infrastructure
- ***Terraform***
- AWS ***EC2***
- AWS ***VPC***, including security groups and subnets
- AWS ***S3***
- ***CloudFlare*** DNS Records
- ***Debian Linux*** used for both the NGINX and Kubernetes servers
- ***NGINX*** as a reverse-proxy
- ***Kubernetes***
- ***K3S*** distribution of Kubernetes
- ***GitHub Actions*** coming soon...used to make updates to the servers that reflect changes in the HTML (and maybe other) files

### Kubernetes Tools
- ***Helm*** used to template and deploy the Kubernetes manifests
- ***1Password Connect Server*** runs in Kubernetes to help with secrets automation
- ***Docker*** used to install build dependencies for the Go app

### Programming Languages
- ***Golang*** for the `memes-api`
- ***Bash***, most of which is in the `scripts` directory and the `Makefile`.
- ***PostgreSQL*** for the `memes` database

### Other
- ***1Password CLI*** makes it easy to open source my code without compromising secrets, and helps with secrets automation
