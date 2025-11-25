## Authlance license
Place your Authlance license file in this folder and point `AUTH_LICENSE_FILE` (in `.env`) to it. The default path we expect is:

```
./deployment/docker-compose/licenses/authlance.lic
```

Inside the container the file is mounted at `/app/config/authlance.lic`, so ensure the auth template uses the same location:

```
LICENSE_PATH=/app/config/authlance.lic
```

## Licenseoperator license
The compose template ships a trial license at `templates/app/license/trialLicense` that gets copied into the rendered config volume. To use your own signed license instead, overwrite that file or mount your own path and update these variables in `.env`:

```
LO_LICENSE_FILE_PATH=/config/license/your-license-file
LO_LICENSE_EXPECTED_DOMAIN=.example.com
LO_LICENSE_GRACE_DAYS=30
LO_LICENSE_REFRESH_INTERVAL=15m
```

After changing the file, re-render configs with:

```
docker compose up --no-deps --force-recreate ory-templates
```
