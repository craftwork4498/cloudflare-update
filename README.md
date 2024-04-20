# Cloudflare Update

## Example

```nix
{
  imports = [inputs.cloudflare-update.nixosModules.default];
  config = {
    sops.secrets.cloudflare_apikey = { };

    services.cloudflare-update = {
      enable = true;
      zones."example.com" = {
        apiKeyPath = config.sops.secrets.cloudflare_apikey.path;

        records = [
          {
            name = "localhost.example.com";
            type = "A";
            content = "127.0.0.1";
            comment = "configured by nix";
            proxied = false;
          }
        ];
      };
    };
  };
}
```
