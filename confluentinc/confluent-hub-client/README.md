# Confluent Hub Client

## Installing Confluent Hub Client

The Confluent Hub client is natively installed as a part of the complete Confluent Platform and located in the `/bin` directory. If you are using Confluent Community software, you can install the Confluent Hub client separately using the following instructions.

### Linux

Download and unzip the Confluent Hub tarball.

1. Copy and paste this link in your browser to download and unzip the Confluent Hub tarball.

```
http://client.hub.confluent.io/confluent-hub-client-latest.tar.gz
```

2. Add the contents of the `bin` directory to your PATH environment variable so that `which confluent-hub` finds the `confluent-hub` command.

3. Optional: Verify your installation by typing `confluent-hub` in your terminal.

```
confluent-hub
```

Your output should look like this:

```
usage: confluent-hub <command> [ <args> ]

Commands are:
    help      Display help information
    install   install a component from either Confluent Hub or from a local file

See 'confluent-hub help <command>' for more information on a specific command.
```
