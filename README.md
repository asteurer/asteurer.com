# Overview

This is the source code for [asteurer.com](https://asteurer.com).

## Technologies

- The infrastructure for this website is managed with ***Terraform***, which was chosen because the project uses resources from both ***AWS*** and ***CloudFlare***.
- Various ***Python*** and ***Bash*** scripts were written so the website could be up-and-running from scratch in less than 10 minutes.
- The front-end of the project is PHP and HTML files served via ***NGINX***, and encrypted with ***SSL certificates***.
- The back-end portion is a ***Kubernetes*** cluster, running a ***Helm*** deployment containing ***Postgres*** and ***Golang*** applications.
- ***Secrets automation*** is accomplished using 1Password's CLI and Kubernetes Connect Server.