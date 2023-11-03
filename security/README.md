# Risky Linux Capabilities
Some Linux capabilities can be dangerous if they are available in containerized environments because they can allow the container to 'break out of its isolation' and affect the host system or other containers. Dropping these capabilities minimizes risks and reduces the attack surface.

Here’s a brief overview of some of the capabilities that are considered risky when working with containers:

**CAP_SYS_ADMIN**: Powerful capabilities because it allows a process to perform a wide range of system administration operations with 'root' permissions which can affect the host system and other containers.

**CAP_NET_ADMIN**: Allows various network-related operations that could be used to disrupt the network configuration of the host or 'eavesdrop' on other containers' network traffic.

**CAP_SYS_MODULE**: Allows loading and unloading kernel modules. If granted to a container, it could load a compromised kernel module and compromise the host.

**CAP_SYS_RAWIO**: Permits raw I/O access to the system which could be used to read or write to disk devices or other hardware.

**CAP_SYS_PTRACE**: Can be used to trace system calls of other processes. If a container has this capability, it could potentially attach to processes running outside the container.

**CAP_DAC_OVERRIDE** and **CAP_DAC_READ_SEARCH**: These capabilities allow bypassing file read, write, and execute permission checks as well as directory read and execute permission checks. This can be used to access or modify files that the container should not have access to.

**Note:** When running containers, it's best practice to follow the principle of least privilege, which means granting only the capabilities that are absolutely necessary for the container to run its applications. In general, it is not necessary to grant additional capabilities beyond the default set provided by Docker.


## The included script can check for the above capabilities

To run the script 
```
curl -O xxxxx
chmod +x linuxCapabilities.sh
sh linuxCapabilities.sh
```

# Dropping a capability in Docker
Docker, runs containers with a default set of capabilities and allows you to drop capabilities that are not needed or add ones that are required using the `--cap-drop` and `--cap-add` options when running a container.

The below sample will drop `CAP_SYS_ADMIN` capability when starting a Docker container:

```bash
docker run --cap-drop=CAP_SYS_ADMIN myimage
```


