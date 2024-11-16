<div align="center">
<a href="https://github.com/vincetrain/samba"><img src="https://raw.githubusercontent.com/dockur/samba/master/.github/logo.png" title="Logo" style="max-width:100%;" width="256" /></a>
</div>
<div align="center">

</div></h1>

Docker container of [Samba](https://www.samba.org/), an implementation of the Windows SMB networking protocol.

Original container forked from [dockur/samba](https://github.com/dockur/samba).

This fork is configured to focus more on implementing a multi-user share using Samba homes shares.

## TODO:
- [x] Hide plaintext passwords in users (if possible/needed)
- [x] Add support for automatic creation of shared shares (with groups)
- [ ] Create a script for easy management of users

## Usage  🐳

Via Docker Compose:

```yaml
services:
  samba:
    image: dockurr/samba
    container_name: samba
    ports:
      - 445:445
    volumes:
      - /home/example/data:/storage
```

Via Docker CLI:

```bash
docker run -it --rm -p 445:445 -v "/home/example/data:/storage" vincetrain/samba
```

Default credentials are samba:secret, but changing these credentials is recommended.

## Configuration ⚙️

### How do I connect to a share?

You can connect to a share by using the following address: [server-address]/[user name]

On Windows Explorer, this looks like `\\192.168.2.2\samba`, where "192.168.2.2" is replaced with the address of the server behind this container, and "samba" is replaced by the username".

By default this container is configured to host a share for user "samba" with password "secret".  

### How do I modify the default credentials or add more users?

You can change the default credentials or add more users inside the provided [users](https://github.com/vincetrain/samba/blob/master/secret/users) file, and binding the file to `/run/secrets/users`, or using the file as a Docker secret if working with Docker swarms.

Passwords are stored as NTLM MD4 hashes. To generate a NTLM MD4 hash, consider using the following command:

`iconv -f ASCII -t UTF-16LE <(printf "password") | openssl dgst -MD4 -provider legacy | cut -d " " -f2`

replacing "password" with the desired user's password.

### How can I implement a group share?

You can implement group shares by modifying the provided [groupshares](https://github.com/vincetrain/samba/blob/master/secret/groupshares) file, and binding the file to `/run/secrets/groupshares`, or using the file as a Docker secret if working with Docker swarms.

### How do I modify other settings?

If you need more advanced features, you can completely override the default configuration by modifying the [smb.conf](https://github.com/vincetrain/samba/blob/master/smb.conf) file in this repo, and binding your custom config to the container like this:

```yaml
volumes:
  - /example/smb.conf:/etc/samba/smb.conf
```
## Building  🔨
Build with buildkit!

Run:
`DOCKER_BUILDKIT=1 docker build . -t [registry:tag]` inside of this repository's directory.

Or have the following configuration in your `daemon.json`
```json
{
    "features": {
        "buildkit": true
    }
}
```
And build normally.

For more information, refer to the [offical dockerdocs](https://docs.docker.com/build/buildkit/#getting-started)
