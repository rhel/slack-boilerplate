# slack-boilerplate

## Setup

```bash
git clone https://github.com/rhel/slack-boilerplate.git
cd slack-boilerplate/terraform/
terraform init
terraform apply
```

## Configure

- open [https://api.slack.com/apps](https://api.slack.com/apps)
- click the "Create New App" button
- use the "Slash Commands" link located in the sidebar
- use `boilerplate_url` to fill the "Request URL" parameter
![command.png](https://github.com/rhel/slack-boilerplate/blob/master/images/command.png?raw=true)
