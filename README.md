# Moodle on Render

One container runs Apache + PHP and Moodle's cron (via supervisord). Uploaded files and SCORM packages live on a Render persistent disk; data lives in Render PostgreSQL.

## Deploy

1. Push this folder to a GitHub repo.
2. In Render: **New → Blueprint**, pick the repo. Render reads `render.yaml`.
3. When prompted, fill in:
   - `MOODLE_WWWROOT` — the exact public URL (no trailing slash). If you'll use a custom domain, set that now; changing it later means updating stored URLs.
   - `MOODLE_ADMIN_PASSWORD` — strong password for the local `admin` account (8+ chars, mixed case, digit, symbol, or Moodle's install rejects it).
   - `MOODLE_ADMIN_EMAIL`
4. First deploy installs the database (a few minutes). Log in at `/login/index.php` as `admin`.

## Microsoft 365 plugin suite

The image includes Microsoft's official Moodle plugins, cloned at build time from `github.com/microsoft/o365-moodle` on the branch matching `MOODLE_VERSION` (e.g. `MOODLE_502_STABLE`): OpenID Connect sign-in (`auth_oidc`), the integration core (`local_o365`), the Microsoft block, OneDrive/SharePoint repository, Teams theme and meeting button, and OneNote assignment plugins. They install with Moodle on first deploy, and on upgrades the entrypoint picks up new plugin versions.

- Leave it out: set build arg `INSTALL_O365=0`.
- If the build fails saying the branch isn't found (Microsoft can lag a new Moodle release), set `O365_BRANCH` to the newest available branch, or stay on the previous `MOODLE_VERSION`.
- Don't install or update plugins from Moodle's web UI — the code directory isn't persistent, so changes vanish on the next deploy. Rebuild the image instead (a redeploy pulls the latest fixes on the branch).

### Connect to Entra

Recommended: in Moodle go to **Site administration → Plugins → Local plugins → Microsoft 365 Integration → Setup**, download the PowerShell script (PowerShell 7.5+), and run it as an Entra admin. It creates the app registration with the right Microsoft Graph permissions and gives you the IDs to paste back.

Manual route:

1. Entra admin center → App registrations → New registration. Single tenant. Redirect URI (Web): `https://YOUR-URL/auth/oidc/` — the trailing slash is required.
2. Create a client secret; note the Application (client) ID and Directory (tenant) ID.
3. Add the Microsoft Graph API permissions listed on the Moodle Microsoft 365 setup page and grant admin consent.
4. Moodle: **Plugins → Authentication → OpenID Connect** — enter client ID, secret, and your tenant-specific endpoints (not `common`), so only your organization can sign in.
5. **Plugins → Authentication → Manage authentication** — enable **OpenID Connect**.
6. **Microsoft 365 Integration** — complete setup, then on **Sync settings** turn on user sync:
   - create Moodle accounts for Entra users (optionally scoped to a group),
   - update profile details,
   - suspend accounts when users are disabled or deleted in Entra (handles offboarding).
   User sync runs as a scheduled task through the container's cron.
7. Optional: map Moodle cohorts to Microsoft 365 groups (e.g. one cohort per store or department) to drive course enrolment.

Keep the local `admin` account as break-glass access.

## Upgrading Moodle

Change `MOODLE_VERSION` in the Dockerfile and redeploy. The entrypoint runs the upgrade automatically. Snapshot the disk and DB first.

## Notes

- One instance only (persistent disk). Deploys cause a brief outage; deploy after hours.
- Cron runs every minute inside the container — don't add a Render Cron Job.
- Backups: Render snapshots the disk daily and backs up Postgres. Test restoring both to the same point in time.
- PHP timezone is in `docker/moodle.ini`.
