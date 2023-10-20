# SSH Tarpit with babashka, terraform and AWS SSM


This is a small experiment in tarpitting ssh robots. It runs a server on port
22 and awaits robots to try to connect and exploit. But instead of giving them
a shell it sends infinite stream of rubbish and never lets the clients rally
connect. If you try to connect with standard ssh client without a timeout it
will hang there infinitely listening to the rubbish received.

> [!WARNING]
> Connecting unaudited code to the Internet is dangerous. Read the whole
> thing (this README as well as the other files) and only deploy if you understand and
> accept the risks.


The tarpit server itself is written in babashka (clojure) and it is an under-100-loc
easy-to-read unaudited proof-of-concept. But it works and is easy to modify if you have
ideas about how to better tarpit the robots - just modify the
[`process-one-client` function](ssh-tarpit.clj#L27-L46).

Deployment is done through terraform.
Defaults to eu-central-1. Deploys to default vpc, so you might want to deploy
to an account dedicated just for this or add the vpc yourself.

Because the tarpit tarpits on port 22, there are a few special things about the
deployment. Debian 12 is used, but ssh-server is uninstalled. Instead AWS SSM
Agent is installed on the instance and you can use SSM sessions to get
interactive access to the logs etc. (see [ssm-session.sh](ssm-session.sh) for
how to connect to the running instance)

Because the script is so short, there is no need to create custom AMI or other
ways to customize the image. All customization is in user-data and
[cloud-init](cloud-config.yaml),
including the [whole script](ssh-tarpit.clj) itself.

As a bonus the tarpit reports custom metrics to CloudWatch - number of
connected clients and average connection duration. Both in namespace `Tarpit`.

The file [log.txt](log.txt) contains logs from runnig this for over a week.
I am a bit dissapointed that most of the robots have timeouts and disconnect
after a few seconds, just a few were tarpiting for minutes. I ran a similar tarpit 3 years ago and I got wastly
different results with hundreds of robots tarpiting for hours. Maybe the robot
farms got wiser, or the tarpiting logic needs to be more clever.

## Usage

### deploy with teraform

``` terraform
terraform init
terraform apply
```

### use SSM session to follow the logs
```
./tail-logs.sh
```

### connect with nc to see if it is working, logging etc.
```
./test-it.sh
```

### experiment with other tarpiting logic
```
vi ssh-tarpit.clj
terraform apply
```
and repeat

### cleanup
```
terraform destroy
```
