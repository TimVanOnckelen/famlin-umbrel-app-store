# Famlin Umbrel App Store

An [Umbrel](https://umbrel.com) community app store for
[Famlin](https://famlin.app), the private, self-hosted app for family updates,
photos, milestones, stories and trips. Installing it gives you the Famlin
server plus its own PostgreSQL database, with no configuration: the database
password and signing secret are generated for you.

## Add the store

1. In umbrelOS open the **App Store**.
2. Click the three dots (top right) and choose **Community App Stores**.
3. Paste `https://github.com/TimVanOnckelen/famlin-umbrel-app-store` and add it.
4. Open the new store, choose **Famlin** and click **Install**.
5. Click **Open** and create the first (administrator) account.

Full guide: https://famlin.app/docs/install-umbrel-casaos

## Remote access

Family members use the phone apps away from home, so the server must be
reachable from outside. For yourself, Umbrel's Tailscale app works well. For
your family, who should not need a VPN, put Famlin behind a Cloudflare Tunnel:
https://famlin.app/docs/cloudflare-tunnel. The app already trusts Umbrel's
proxy headers (`TRUST_PROXY=true`).

Umbrel's own login is turned off in front of Famlin (`PROXY_AUTH_ADD: "false"`),
because Famlin has its own accounts and the phone apps call the API directly.

## Layout

```
umbrel-app-store.yml     store id and name
famlin-famlin/           app id = <store id>-<app name>
  umbrel-app.yml         listing
  docker-compose.yml     app_proxy + server + postgres
```

Data lives in `${APP_DATA_DIR}/data/{db,uploads,backups,secrets}`.

## Maintainers

### Bump the version

Run the **Bump Famlin version** workflow (Actions tab) with the new version, or
send a `famlin-release` repository dispatch with `client_payload.version`. It
opens a PR that updates three things:

- the image tag and digest in `famlin-famlin/docker-compose.yml`
- `version` in `famlin-famlin/umbrel-app.yml`
- `releaseNotes` (a link to the Famlin release)

By hand: `docker buildx imagetools inspect ghcr.io/timvanonckelen/famlin:<version>`
and use the top-level (index) digest as `image: ...:<version>@sha256:<digest>`.
Umbrel offers the update when `version` changes.

### Submit to the official store

Open a PR against [getumbrel/umbrel-apps](https://github.com/getumbrel/umbrel-apps)
with the app folder renamed to `famlin`, `id: famlin` in `umbrel-app.yml` and
`APP_HOST: famlin_server_1` / `POSTGRES_HOST: famlin_db_1` in the compose file
(the store prefix `famlin-` is dropped). The official store also wants a
digest-pinned `postgres` image, an SVG icon and 3 to 5 screenshots hosted in the
umbrel-apps gallery repository.

## License

MIT, see [LICENSE](LICENSE).
