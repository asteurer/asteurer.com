# Overview
This is the source code for [asteurer.com](https://asteurer.com).

## Features
- I am able to text meme images to a Telegram bot, and the memes will be accessible on the website

## Technologies

- The website is run on a ***Fedora Linux*** virtual machine on a server in my apartment, and is accessible via ***Cloudflare Tunnels***.
- ***Terraform*** is used to spin up an ***AWS S3*** bucket with an accompanying service account for the `meme-manager` application
- I used ***Svelte*** (a JavaScript framework) for the front end.
- The back-end portion is a ***Docker Compose*** stack running ***Postgres*** and ***Golang*** applications.
- The `db-client` application has ***automated tests***
- In the `Makefile`, I automated various repetitive tasks, improving my development workflow

## Design
![image](README_files/diagram.svg)

### Telegram Bot and meme-manager
- Sending image data to S3 via an API was tedious and exposed PUT and DELETE operations to the public internet. Telegram made it possible to manage the image data by pulling from Telegram's servers via `meme-manager`, rather than having to manage authentication for pushing directly to the website's servers.

### Front end state management
- I wanted a user to be able to traverse memes and retrace their steps without having to store any session data. I decided to use a linked-list, and routes as a way to retrieve the image data for the previous and next memes.

### Cloudflare Tunnels
- I used Cloudflare Tunnels because I wanted to host my website on my home server, but I didn't want to have to expose my home IP address or manage a complex firewall.