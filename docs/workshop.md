# IPPCP API workshop

This is the executable Golden Path. Copy and paste the command blocks in order from the repository root.

A new technical user can complete the current IPPCP API workflow from a clean clone by following this document. Detailed explanations live in the [reference documentation](#16-reference-documentation).

## 0. What this workshop does

You will:

1. prepare the machine;
2. create ignored local credential files;
3. configure the Ingestion API secret if you will run that asset;
4. execute Phase 0 through Phase 4 for each current asset;
5. validate the downloaded content semantically;
6. inspect runtime traceability;
7. package evidence.

Current assets and the same technical lifecycle:

| Resource | `IPPCP_FLOW` | Provider | Consumer | Configuration |
| --- | --- | --- | --- | --- |
| Ingestion API | `ingesta` | `conn-citycouncil-ippcp` | `conn-company-ippcp` | `ingesta_api_pull_pre_api_key.json` |
| WFS city | `consumo` | `conn-citycouncil-ippcp` | `conn-company-ippcp` | `emisiones_wfs_ciudad_geojson.json` |
| WFS districts / juntas | `consumo` | `conn-citycouncil-ippcp` | `conn-company-ippcp` | `emisiones_wfs_juntas_geojson.json` |
| SPARQL Results JSON | `consumo` | `conn-citycouncil-ippcp` | `conn-company-ippcp` | `emisiones_sparql_limit10_format_json.json` |

```text
phase0 -> phase1 -> phase2 -> phase3 -> phase4
```

- Phase 0: context, technical provider/consumer login, smoke checks.
- Phase 1: policies, asset, data address, contract definition.
- Phase 2: catalog discovery, negotiation, agreement.
- Phase 3: transfer process and Endpoint Data Reference (EDR).
- Phase 4: current EDR, Data Plane download, manifest, SHA-256.

The current Golden Path is `v2` `HttpData-PULL`. CSV/B2/InesDataStore, `v1`, `test3`, and `phase1b` / `phase3b` / `phase4b` are historical only. Do not mix them into this workshop.

You need Git access, EdD technical credentials supplied separately, and the Ingestion API secret supplied separately if you run that asset. You do not need prior IPPCP knowledge.

MinIO Client (`mc`) is not required for the four current `HttpData-PULL` assets.

## 1. Clone the repository

All later commands run from the repository root unless a block says otherwise.

```bash
git clone https://github.com/JPardo08/ippcp-API.git
cd ippcp-API
```

Confirm the root:

```bash
git status -sb
git log -1 --oneline
test -f endpoints.sh && test -f export_suffix.sh && test -f scripts/lib_common.sh && echo "OK repository root"
```

**Expected result:** you are in the repository root and the three files exist.

**STOP if:** the checkout is incomplete or you are not in the repository root.

## 2. Install prerequisites

Required:

- Bash 4.3 or newer.
- Git.
- `curl`.
- `jq`.
- Python 3, recommended for diagnostics.
- Python 3.10 or newer is required later for evidence tooling. Conda is not required.

Technical users must be able to authenticate without human interaction. Mandatory OTP/MFA or pending required actions block the automated flow.

### 2.1 macOS

Check Homebrew:

```bash
command -v brew
brew --version
```

Install Homebrew first if `brew` is missing.

Install tools:

```bash
brew install bash jq python
```

Select modern Bash:

```bash
export BASH_BIN="$(brew --prefix)/bin/bash"

"${BASH_BIN}" --version | head -1
command -v git
command -v curl
command -v jq
command -v python3
```

**Expected result:** Bash reports `4.3` or newer. `git`, `curl`, `jq`, and `python3` are on `PATH`.

Typical Homebrew Bash locations:

- Apple Silicon: `/opt/homebrew/bin/bash`
- Intel: `/usr/local/bin/bash`

**STOP if:** Bash is older than 4.3 or a required command is missing.

### 2.2 Linux / WSL

Detect the package manager:

```bash
if command -v apt-get >/dev/null 2>&1; then
  echo "PACKAGE_MANAGER=apt"
elif command -v dnf >/dev/null 2>&1; then
  echo "PACKAGE_MANAGER=dnf"
elif command -v yum >/dev/null 2>&1; then
  echo "PACKAGE_MANAGER=yum"
elif command -v zypper >/dev/null 2>&1; then
  echo "PACKAGE_MANAGER=zypper"
elif command -v pacman >/dev/null 2>&1; then
  echo "PACKAGE_MANAGER=pacman"
else
  echo "No supported package manager detected by this workshop"
fi
```

Use **only** the block that matches the detected manager.

APT / Ubuntu / Debian / WSL Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y bash git curl jq python3
```

DNF / Fedora / modern RHEL:

```bash
sudo dnf install -y bash git curl jq python3
```

YUM / older RHEL-like distributions:

```bash
sudo yum install -y bash git curl jq python3
```

Zypper / openSUSE:

```bash
sudo zypper install -y bash git curl jq python3
```

Pacman / Arch:

```bash
sudo pacman -S --needed bash git curl jq python
```

Select Bash:

```bash
export BASH_BIN="$(command -v bash)"

"${BASH_BIN}" --version | head -1
command -v git
command -v curl
command -v jq
command -v python3
```

**Expected result:** Bash is 4.3 or newer and the required commands exist.

**STOP if:** Bash is too old or a required command is missing.

### 2.3 Optional static checks

```bash
jq empty asset_configs/real/ingesta/ingesta_api_pull_pre_api_key.json
jq empty asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json
jq empty asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json
jq empty asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json
echo "OK configs"

BASH_CHECK="${BASH_BIN:-$(command -v bash)}"
"${BASH_CHECK}" -n scripts/phase0_context_smoke.sh
"${BASH_CHECK}" -n scripts/phase1_provider_publish.sh
"${BASH_CHECK}" -n scripts/phase2_consumer_negotiate.sh
"${BASH_CHECK}" -n scripts/phase3_transfer_edr.sh
"${BASH_CHECK}" -n scripts/phase4_save_download.sh
echo "OK scripts"
```

Do not syntax-check `phase1b` / `phase3b` / `phase4b` as part of this workshop. Those scripts belong to the historical B2 path.

## 3. Create local technical-user files

The repository does not include real credentials. A clean clone fails Phase 0 until the ignored local files exist.

```bash
cp flujos/ippcp/v2/ingesta/user_provider.example.sh \
   flujos/ippcp/v2/ingesta/user_provider.sh

cp flujos/ippcp/v2/ingesta/user_consumer.example.sh \
   flujos/ippcp/v2/ingesta/user_consumer.sh

cp flujos/ippcp/v2/consumo/user_provider.example.sh \
   flujos/ippcp/v2/consumo/user_provider.sh

cp flujos/ippcp/v2/consumo/user_consumer.example.sh \
   flujos/ippcp/v2/consumo/user_consumer.sh
```

Edit the four files and replace `CHANGE_ME` with the technical credentials supplied to you:

```bash
export PROVIDER_USERNAME="CHANGE_ME"
export PROVIDER_PASSWORD="CHANGE_ME"
```

```bash
export CONSUMER_USERNAME="CHANGE_ME"
export CONSUMER_PASSWORD="CHANGE_ME"
```

The files are split by flow because that is how the repository is organized. This does not require four different accounts. The same provisioned technical user may be reused when it has permission on the configured connectors.

**Expected result:** all four `user_*.sh` files exist and no longer contain `CHANGE_ME`.

**STOP if:** credentials are missing, still set to `CHANGE_ME`, or you are about to paste passwords into documentation, commits, screenshots, or chat.

Do not commit these files.

## 4. Configure the Ingestion API secret

WFS and SPARQL do not need extra upstream credentials. Ingestion API does: the provider-side hop requires `X-Api-Key` and a numeric `X-Provider-Id`.

```bash
cp data/real/ingesta/auth/ingesta_api_key.env.example \
   data/real/ingesta/auth/ingesta_api_key.env
```

Edit the local file:

```bash
export INGESTA_API_KEY="REPLACE_ME"
export INGESTA_API_PROVIDER_ID="1"
```

- `INGESTA_API_KEY`: the Ingestion API key supplied to you.
- `INGESTA_API_PROVIDER_ID`: numeric identifier expected by the upstream application. It is **not** a Keycloak UUID.
- These values stay on the provider boundary. They are not given to the consumer and are not placed in the EDR.

If you will run only WFS/SPARQL in this session, you may skip this file until you run Ingestion API. Phase 1 of Ingestion API will fail without it.

**Expected result:** `data/real/ingesta/auth/ingesta_api_key.env` exists locally and is not committed.

**STOP if:** you need Ingestion API and the file is missing, still contains `REPLACE_ME`, or you are about to print the key.

## 5. Verify secrets are ignored by Git

```bash
git status --short
```

```bash
git check-ignore \
  flujos/ippcp/v2/ingesta/user_provider.sh \
  flujos/ippcp/v2/ingesta/user_consumer.sh \
  flujos/ippcp/v2/consumo/user_provider.sh \
  flujos/ippcp/v2/consumo/user_consumer.sh \
  data/real/ingesta/auth/ingesta_api_key.env
```

**Expected result:** the command lists all five paths. Local credential files must not appear as versionable changes.

**STOP if:** any of the five paths is missing from `git check-ignore`. Do not continue and do not commit until `.gitignore` is corrected.

## 6. Ingestion API — complete run

Prerequisites:

- `BASH_BIN` selected.
- Ingestion `user_provider.sh` and `user_consumer.sh` exist.
- `ingesta_api_key.env` exists.
- Git ignores those files.

Each asset needs its own Phase 0 and `SUFFIX`. Start Ingestion API from a reset shell context.

### 6.1 Phase 0

```bash
export BASH_BIN="${BASH_BIN:-$(command -v bash)}"
set +x

unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_DATASPACE=ippcp
export IPPCP_FLOW=ingesta
export IPPCP_FLOW_VERSION=v2

"${BASH_BIN}" scripts/phase0_context_smoke.sh
```

Only after success:

```bash
source runtime/env/latest/phase0_env.sh

echo "SUFFIX=$SUFFIX"
echo "IPPCP_FLOW=$IPPCP_FLOW"
test -f runtime/env/latest/phase0_env.sh && echo "OK phase0_env"
```

**Expected result:** Phase 0 exits successfully, `phase0_env.sh` exists, and `SUFFIX` is set.

**STOP if:** Phase 0 fails, `phase0_env.sh` is missing, or you see `Missing local credentials file`. Return to [section 3](#3-create-local-technical-user-files). Do not run Phase 1.

### 6.2 Phase 1

Load the upstream secret only for publication. Check length, not the key value:

```bash
source runtime/env/latest/phase0_env.sh
source data/real/ingesta/auth/ingesta_api_key.env

echo "INGESTA_API_KEY_LEN=${#INGESTA_API_KEY}"
echo "INGESTA_API_PROVIDER_ID=$INGESTA_API_PROVIDER_ID"

export ASSET_CONFIG="asset_configs/real/ingesta/ingesta_api_pull_pre_api_key.json"

"${BASH_BIN}" scripts/phase1_provider_publish.sh

unset INGESTA_API_KEY INGESTA_API_PROVIDER_ID

source runtime/env/latest/phase1_env.sh
```

**Expected result:**

```bash
test -n "${SUFFIX:-}" && echo "SUFFIX=$SUFFIX" || echo "FAIL SUFFIX"
test -n "${ASSET_ID:-}" && echo "ASSET_ID=$ASSET_ID" || echo "FAIL ASSET_ID"
test -n "${CD_ID:-}" && echo "CD_ID=$CD_ID" || echo "FAIL CD_ID"
test -f runtime/env/latest/phase1_env.sh && echo "OK phase1_env" || echo "FAIL phase1_env"
jq '.phases.phase1' "evidencias/runs/${SUFFIX}/summary.json"
```

`INGESTA_API_KEY` and `INGESTA_API_PROVIDER_ID` are unset before Phase 2. Phases 2–4 do not need them. The consumer never receives those values.

**STOP if:** Phase 1 fails, `phase1_env.sh` is missing, `ASSET_ID` is empty, or you see `HTTP 409`. A 409 means an object with the derived identifier already exists; start a **new** run from Phase 0. Do not try to mutate a published asset data address.

### 6.3 Phase 2

```bash
source runtime/env/latest/phase1_env.sh

"${BASH_BIN}" scripts/phase2_consumer_negotiate.sh

source runtime/env/latest/phase2_env.sh
```

**Expected result:**

```bash
test -n "${AGREEMENT_ID:-}" && echo "AGREEMENT_ID=$AGREEMENT_ID" || echo "FAIL AGREEMENT_ID"
test -f runtime/env/latest/phase2_env.sh && echo "OK phase2_env" || echo "FAIL phase2_env"
jq '.phases.phase2' "evidencias/runs/${SUFFIX}/summary.json"
```

**STOP if:** `AGREEMENT_ID` is empty, negotiation ends `TERMINATED`, or `phase2_env.sh` is missing.

### 6.4 Phase 3

```bash
source runtime/env/latest/phase2_env.sh

"${BASH_BIN}" scripts/phase3_transfer_edr.sh

source runtime/env/latest/phase3_env.sh
```

**Expected result:**

```bash
test -n "${TRANSFER_ID:-}" && echo "TRANSFER_ID=$TRANSFER_ID" || echo "FAIL TRANSFER_ID"
test -n "${EDR_URL:-}" && echo "EDR_URL_SET=yes" || echo "FAIL EDR_URL"
test -f runtime/env/latest/phase3_env.sh && echo "OK phase3_env" || echo "FAIL phase3_env"
jq '.phases.phase3' "evidencias/runs/${SUFFIX}/summary.json"
```

Do **not** print EDR authorization.

**STOP if:** `TRANSFER_ID` is empty, EDR URL is missing, or `phase3_env.sh` is missing.

### 6.5 Phase 4

```bash
source runtime/env/latest/phase3_env.sh

"${BASH_BIN}" scripts/phase4_save_download.sh
```

Phase 4 is terminal. It does not create `phase4_env.sh`.

**Expected result:** a non-empty download and manifest exist:

```bash
DOWNLOAD_FILE="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"
MANIFEST_FILE="downloads/manifests/${ASSET_ID}/latest.manifest.json"

test -s "${DOWNLOAD_FILE}" && echo "OK download: ${DOWNLOAD_FILE}" || echo "FAIL download"
test -s "${MANIFEST_FILE}" && echo "OK manifest: ${MANIFEST_FILE}" || echo "FAIL manifest"
jq '{suffix, asset_id, bytes, media_type, sha256}' "${MANIFEST_FILE}"
jq '.phases.phase4' "evidencias/runs/${SUFFIX}/summary.json"
```

### 6.6 Semantic validation

HTTP 200 is not enough. The Ingestion API download must be valid JSON:

```bash
DOWNLOAD_FILE="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"

jq empty "${DOWNLOAD_FILE}" && echo "OK — Ingestion API returned valid JSON"
```

Do not print the payload if it may contain unapproved business data.

Keep this run identity for later evidence packaging:

```bash
export INGESTION_SUFFIX="$SUFFIX"
export INGESTION_ASSET_ID="$ASSET_ID"
echo "INGESTION_SUFFIX=$INGESTION_SUFFIX"
```

**STOP if:** `jq empty` fails, the download is empty, or phase 4 is not `ok`.

## 7. WFS city — complete run

Prerequisites:

- Consumption `user_provider.sh` and `user_consumer.sh` exist.
- Do **not** reuse the Ingestion API `SUFFIX` or `runtime/env/latest` from section 6.
- Do not source `ingesta_api_key.env`.

### 7.1 Phase 0

```bash
export BASH_BIN="${BASH_BIN:-$(command -v bash)}"
set +x

unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_DATASPACE=ippcp
export IPPCP_FLOW=consumo
export IPPCP_FLOW_VERSION=v2

"${BASH_BIN}" scripts/phase0_context_smoke.sh
```

Only after success:

```bash
source runtime/env/latest/phase0_env.sh

echo "SUFFIX=$SUFFIX"
echo "IPPCP_FLOW=$IPPCP_FLOW"
test -f runtime/env/latest/phase0_env.sh && echo "OK phase0_env"
```

**STOP if:** Phase 0 fails or `phase0_env.sh` is missing. Do not run Phase 1.

### 7.2 Phase 1

```bash
source runtime/env/latest/phase0_env.sh
export ASSET_CONFIG="asset_configs/real/consumo/wfs/emisiones_wfs_ciudad_geojson.json"

"${BASH_BIN}" scripts/phase1_provider_publish.sh
```

Only after success:

```bash
source runtime/env/latest/phase1_env.sh

test -n "${SUFFIX:-}" && echo "SUFFIX=$SUFFIX" || echo "FAIL SUFFIX"
test -n "${ASSET_ID:-}" && echo "ASSET_ID=$ASSET_ID" || echo "FAIL ASSET_ID"
test -f runtime/env/latest/phase1_env.sh && echo "OK phase1_env" || echo "FAIL phase1_env"
```

**STOP if:** Phase 1 fails, `phase1_env.sh` is missing, or `ASSET_ID` is empty. Do not run Phase 2.

### 7.3 Phase 2

```bash
source runtime/env/latest/phase1_env.sh

"${BASH_BIN}" scripts/phase2_consumer_negotiate.sh
```

Only after success:

```bash
source runtime/env/latest/phase2_env.sh

test -n "${AGREEMENT_ID:-}" && echo "AGREEMENT_ID=$AGREEMENT_ID" || echo "FAIL AGREEMENT_ID"
test -f runtime/env/latest/phase2_env.sh && echo "OK phase2_env" || echo "FAIL phase2_env"
```

**STOP if:** Phase 2 fails, `phase2_env.sh` is missing, or `AGREEMENT_ID` is empty. Do not run Phase 3.

### 7.4 Phase 3

```bash
source runtime/env/latest/phase2_env.sh

"${BASH_BIN}" scripts/phase3_transfer_edr.sh
```

Only after success:

```bash
source runtime/env/latest/phase3_env.sh

test -n "${TRANSFER_ID:-}" && echo "TRANSFER_ID=$TRANSFER_ID" || echo "FAIL TRANSFER_ID"
test -n "${EDR_URL:-}" && echo "EDR_URL_SET=yes" || echo "FAIL EDR_URL"
test -f runtime/env/latest/phase3_env.sh && echo "OK phase3_env" || echo "FAIL phase3_env"
```

Do **not** print EDR authorization.

**STOP if:** Phase 3 fails, `phase3_env.sh` is missing, or `TRANSFER_ID` is empty. Do not run Phase 4.

### 7.5 Phase 4

```bash
source runtime/env/latest/phase3_env.sh

"${BASH_BIN}" scripts/phase4_save_download.sh
```

Phase 4 is terminal. It does not create `phase4_env.sh`.

**STOP if:** Phase 4 fails.

### 7.6 Semantic validation

HTTP 200 and generic JSON are not enough. The download must be a GeoJSON `FeatureCollection`:

```bash
DOWNLOAD_FILE="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"
MANIFEST_FILE="downloads/manifests/${ASSET_ID}/latest.manifest.json"

jq empty "$DOWNLOAD_FILE" && echo "OK JSON"
jq -e '
  type == "object"
  and .type == "FeatureCollection"
  and (.features | type == "array")
  and all(
    .features[];
    type == "object"
    and .type == "Feature"
    and (.properties | type == "object")
    and (.geometry == null or (.geometry | type == "object"))
  )
' "$DOWNLOAD_FILE" >/dev/null \
  && echo "OK — valid GeoJSON FeatureCollection"

jq '{type, feature_count: (.features | length)}' "$DOWNLOAD_FILE"
jq '{suffix, asset_id, bytes, media_type, sha256}' "$MANIFEST_FILE"
```

```bash
export WFS_CITY_SUFFIX="$SUFFIX"
export WFS_CITY_ASSET_ID="$ASSET_ID"
echo "WFS_CITY_SUFFIX=$WFS_CITY_SUFFIX"
```

**STOP if:** the GeoJSON check fails, even when HTTP 200 succeeded.

## 8. WFS districts / juntas — complete run

Start a **new** Phase 0. Do not reuse the WFS city `SUFFIX`.

### 8.1 Phase 0

```bash
export BASH_BIN="${BASH_BIN:-$(command -v bash)}"
set +x

unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_DATASPACE=ippcp
export IPPCP_FLOW=consumo
export IPPCP_FLOW_VERSION=v2

"${BASH_BIN}" scripts/phase0_context_smoke.sh
```

Only after success:

```bash
source runtime/env/latest/phase0_env.sh

echo "SUFFIX=$SUFFIX"
echo "IPPCP_FLOW=$IPPCP_FLOW"
test -f runtime/env/latest/phase0_env.sh && echo "OK phase0_env"
```

**STOP if:** Phase 0 fails or `phase0_env.sh` is missing. Do not run Phase 1.

### 8.2 Phase 1

```bash
source runtime/env/latest/phase0_env.sh
export ASSET_CONFIG="asset_configs/real/consumo/wfs/emisiones_wfs_juntas_geojson.json"

"${BASH_BIN}" scripts/phase1_provider_publish.sh
```

Only after success:

```bash
source runtime/env/latest/phase1_env.sh

test -n "${SUFFIX:-}" && echo "SUFFIX=$SUFFIX" || echo "FAIL SUFFIX"
test -n "${ASSET_ID:-}" && echo "ASSET_ID=$ASSET_ID" || echo "FAIL ASSET_ID"
test -f runtime/env/latest/phase1_env.sh && echo "OK phase1_env" || echo "FAIL phase1_env"
```

**STOP if:** Phase 1 fails, `phase1_env.sh` is missing, or `ASSET_ID` is empty. Do not run Phase 2.

### 8.3 Phase 2

```bash
source runtime/env/latest/phase1_env.sh

"${BASH_BIN}" scripts/phase2_consumer_negotiate.sh
```

Only after success:

```bash
source runtime/env/latest/phase2_env.sh

test -n "${AGREEMENT_ID:-}" && echo "AGREEMENT_ID=$AGREEMENT_ID" || echo "FAIL AGREEMENT_ID"
test -f runtime/env/latest/phase2_env.sh && echo "OK phase2_env" || echo "FAIL phase2_env"
```

**STOP if:** Phase 2 fails, `phase2_env.sh` is missing, or `AGREEMENT_ID` is empty. Do not run Phase 3.

### 8.4 Phase 3

```bash
source runtime/env/latest/phase2_env.sh

"${BASH_BIN}" scripts/phase3_transfer_edr.sh
```

Only after success:

```bash
source runtime/env/latest/phase3_env.sh

test -n "${TRANSFER_ID:-}" && echo "TRANSFER_ID=$TRANSFER_ID" || echo "FAIL TRANSFER_ID"
test -n "${EDR_URL:-}" && echo "EDR_URL_SET=yes" || echo "FAIL EDR_URL"
test -f runtime/env/latest/phase3_env.sh && echo "OK phase3_env" || echo "FAIL phase3_env"
```

Do **not** print EDR authorization.

**STOP if:** Phase 3 fails, `phase3_env.sh` is missing, or `TRANSFER_ID` is empty. Do not run Phase 4.

### 8.5 Phase 4

```bash
source runtime/env/latest/phase3_env.sh

"${BASH_BIN}" scripts/phase4_save_download.sh
```

Phase 4 is terminal. It does not create `phase4_env.sh`.

**STOP if:** Phase 4 fails.

### 8.6 Semantic validation

HTTP 200 and generic JSON are not enough. The download must be a GeoJSON `FeatureCollection`:

```bash
DOWNLOAD_FILE="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"
MANIFEST_FILE="downloads/manifests/${ASSET_ID}/latest.manifest.json"

jq empty "$DOWNLOAD_FILE" && echo "OK JSON"
jq -e '
  type == "object"
  and .type == "FeatureCollection"
  and (.features | type == "array")
  and all(
    .features[];
    type == "object"
    and .type == "Feature"
    and (.properties | type == "object")
    and (.geometry == null or (.geometry | type == "object"))
  )
' "$DOWNLOAD_FILE" >/dev/null \
  && echo "OK — valid GeoJSON FeatureCollection"

jq '{type, feature_count: (.features | length)}' "$DOWNLOAD_FILE"
jq '{suffix, asset_id, bytes, media_type, sha256}' "$MANIFEST_FILE"
```

```bash
export WFS_JUNTAS_SUFFIX="$SUFFIX"
export WFS_JUNTAS_ASSET_ID="$ASSET_ID"
echo "WFS_JUNTAS_SUFFIX=$WFS_JUNTAS_SUFFIX"
```

**STOP if:** the GeoJSON check fails, even when HTTP 200 succeeded.

## 9. SPARQL — complete run

Start a **new** Phase 0. Use the canonical JSON-format configuration. A SPARQL XML body with HTTP 200 is a failure.

### 9.1 Phase 0

```bash
export BASH_BIN="${BASH_BIN:-$(command -v bash)}"
set +x

unset IPPCP_DATASPACE_FILE IPPCP_DATASPACE_DIR IPPCP_FLOW_DIR
unset SUFFIX ASSET_ID AGREEMENT_ID TRANSFER_ID EDR_URL
unset CD_ID VOCAB_ID ACCESS_POLICY_ID CONTRACT_POLICY_ID

export IPPCP_DATASPACE=ippcp
export IPPCP_FLOW=consumo
export IPPCP_FLOW_VERSION=v2

"${BASH_BIN}" scripts/phase0_context_smoke.sh
```

Only after success:

```bash
source runtime/env/latest/phase0_env.sh

echo "SUFFIX=$SUFFIX"
echo "IPPCP_FLOW=$IPPCP_FLOW"
test -f runtime/env/latest/phase0_env.sh && echo "OK phase0_env"
```

**STOP if:** Phase 0 fails or `phase0_env.sh` is missing. Do not run Phase 1.

### 9.2 Phase 1

```bash
source runtime/env/latest/phase0_env.sh
export ASSET_CONFIG="asset_configs/real/consumo/sparql/emisiones_sparql_limit10_format_json.json"

"${BASH_BIN}" scripts/phase1_provider_publish.sh
```

Only after success:

```bash
source runtime/env/latest/phase1_env.sh

test -n "${SUFFIX:-}" && echo "SUFFIX=$SUFFIX" || echo "FAIL SUFFIX"
test -n "${ASSET_ID:-}" && echo "ASSET_ID=$ASSET_ID" || echo "FAIL ASSET_ID"
test -f runtime/env/latest/phase1_env.sh && echo "OK phase1_env" || echo "FAIL phase1_env"
```

**STOP if:** Phase 1 fails, `phase1_env.sh` is missing, or `ASSET_ID` is empty. Do not run Phase 2.

### 9.3 Phase 2

```bash
source runtime/env/latest/phase1_env.sh

"${BASH_BIN}" scripts/phase2_consumer_negotiate.sh
```

Only after success:

```bash
source runtime/env/latest/phase2_env.sh

test -n "${AGREEMENT_ID:-}" && echo "AGREEMENT_ID=$AGREEMENT_ID" || echo "FAIL AGREEMENT_ID"
test -f runtime/env/latest/phase2_env.sh && echo "OK phase2_env" || echo "FAIL phase2_env"
```

**STOP if:** Phase 2 fails, `phase2_env.sh` is missing, or `AGREEMENT_ID` is empty. Do not run Phase 3.

### 9.4 Phase 3

```bash
source runtime/env/latest/phase2_env.sh

"${BASH_BIN}" scripts/phase3_transfer_edr.sh
```

Only after success:

```bash
source runtime/env/latest/phase3_env.sh

test -n "${TRANSFER_ID:-}" && echo "TRANSFER_ID=$TRANSFER_ID" || echo "FAIL TRANSFER_ID"
test -n "${EDR_URL:-}" && echo "EDR_URL_SET=yes" || echo "FAIL EDR_URL"
test -f runtime/env/latest/phase3_env.sh && echo "OK phase3_env" || echo "FAIL phase3_env"
```

Do **not** print EDR authorization.

**STOP if:** Phase 3 fails, `phase3_env.sh` is missing, or `TRANSFER_ID` is empty. Do not run Phase 4.

### 9.5 Phase 4

```bash
source runtime/env/latest/phase3_env.sh

"${BASH_BIN}" scripts/phase4_save_download.sh
```

Phase 4 is terminal. It does not create `phase4_env.sh`.

**STOP if:** Phase 4 fails.

### 9.6 Semantic validation

HTTP 200 is not enough. The download must be SPARQL Results JSON. XML with HTTP 200 is a failure.

```bash
DOWNLOAD_FILE="downloads/assets/${ASSET_ID}/latest.${ASSET_EXTENSION:-json}"
MANIFEST_FILE="downloads/manifests/${ASSET_ID}/latest.manifest.json"

jq -e '
  type == "object"
  and (.head | type == "object")
  and (.results | type == "object")
  and (.results.bindings | type == "array")
  and all(.results.bindings[]; type == "object")
' "$DOWNLOAD_FILE" >/dev/null \
  && echo "OK — valid SPARQL Results JSON"

jq '{
  vars: .head.vars,
  binding_count: (.results.bindings | length)
}' "$DOWNLOAD_FILE"
jq '{suffix, asset_id, bytes, media_type, sha256}' "$MANIFEST_FILE"
```

```bash
export SPARQL_SUFFIX="$SUFFIX"
export SPARQL_ASSET_ID="$ASSET_ID"
echo "SPARQL_SUFFIX=$SPARQL_SUFFIX"
```

**STOP if:** the SPARQL Results JSON check fails, the body is XML, or you used `emisiones_sparql_limit10.json` instead of `*_format_json.json`.

## 10. Run isolation and SUFFIX

Each asset requires:

- a new Phase 0;
- a new `SUFFIX`.

Do not reuse `runtime/env/latest` from a different asset. Those files are overwritten every time a later run exports phase state.

Recommended order:

1. Ingestion API: Phase 0 → 4, then save `INGESTION_SUFFIX`.
2. WFS city: new Phase 0 → 4, then save `WFS_CITY_SUFFIX`.
3. WFS juntas: new Phase 0 → 4, then save `WFS_JUNTAS_SUFFIX`.
4. SPARQL: new Phase 0 → 4, then save `SPARQL_SUFFIX`.

If another asset overwrote `runtime/env/latest` before the current run was completed, restart that asset from Phase 0.

`runtime/env/latest` is the operational handoff for the run in progress. Run-specific files under `evidencias/runs/<SUFFIX>/` are historical traceability, not a supported resume mechanism.

## 11. Runtime and traceability

```text
run_id = SUFFIX
```

The same `SUFFIX` correlates publication, negotiation, transfer, evidence, download, and manifest.

```text
evidencias/runs/<SUFFIX>/
  phase0/
  phase1/
  phase2/
  phase3/
  phase4/
  summary.json

runtime/env/latest/

downloads/assets/<ASSET_ID>/
  <SUFFIX>.<extension>
  latest.<extension>

downloads/manifests/<ASSET_ID>/
  <SUFFIX>.manifest.json
  latest.manifest.json
```

- `runtime/env/latest/` is the operational handoff for the run in progress.
- Run-specific files under `evidencias/runs/<SUFFIX>/` and `downloads/.../<SUFFIX>.*` are historical traceability.
- `latest.*` is overwritten when a new result is generated for the same `ASSET_ID`. Do not use `latest.*` alone to identify historical evidence.

Inspect the current run without printing secrets:

```bash
RUN_DIR="evidencias/runs/${SUFFIX}"
MANIFEST_FILE="downloads/manifests/${ASSET_ID}/latest.manifest.json"

jq '{suffix, ds_name, started_at, phases}' "$RUN_DIR/summary.json"
jq '{suffix, asset_id, content_kind, extension, media_type, bytes, sha256, latest_file}' "$MANIFEST_FILE"
```

Verify SHA-256 on macOS (`shasum`) or Linux (`sha256sum`):

```bash
MANIFEST_FILE="downloads/manifests/${ASSET_ID}/latest.manifest.json"
LATEST_FILE=$(jq -r '.latest_file' "${MANIFEST_FILE}")
EXPECTED_SHA=$(jq -r '.sha256' "${MANIFEST_FILE}")

if command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA=$(shasum -a 256 "${LATEST_FILE}" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA=$(sha256sum "${LATEST_FILE}" | awk '{print $1}')
else
  echo "No SHA-256 tool found"
  ACTUAL_SHA=""
fi

echo "EXPECTED_SHA=$EXPECTED_SHA"
echo "ACTUAL_SHA=$ACTUAL_SHA"

[ -n "$ACTUAL_SHA" ] && [ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] && echo "OK SHA256" || echo "FAIL SHA256"
```

Prefer the run-specific files when comparing historical runs:

```text
downloads/assets/<ASSET_ID>/<SUFFIX>.<extension>
downloads/manifests/<ASSET_ID>/<SUFFIX>.manifest.json
```

## 12. Full-run success validation

All four current `HttpData-PULL` assets require:

```text
phase0 = ok
phase1 = ok
phase2 = ok
phase3 = ok
phase4 = ok
```

```bash
jq -e '
  .phases.phase0.status == "ok"
  and .phases.phase1.status == "ok"
  and .phases.phase2.status == "ok"
  and .phases.phase3.status == "ok"
  and .phases.phase4.status == "ok"
' "evidencias/runs/${SUFFIX}/summary.json" >/dev/null \
  && echo "OK — complete run" \
  || echo "FAIL — review summary"
```

Also require the semantic check for that asset from sections 6–9.

**STOP if:** any phase is not `ok`, or semantic validation failed.

## 13. Evidence tooling

T1–T4 are **presentation slots**, not asset types.

```text
run  ->  asset classification
asset  ->  critical / publication_profile / publication_safe
```

The tool classifies each run from `summary.json`, asset metadata, phases, and media type. Slot order is arbitrary.

Do not restore the obsolete mapping `T1=CSV`, `T2=WFS`, `T3=SPARQL`, `T4=Ingestion API`. Do not use `--only-tests T4` as the Ingestion API Golden Path.

Practical commands below. Semantics: [tools/tools_README.md](../tools/tools_README.md), [tools/evidence_tooling.md](../tools/evidence_tooling.md), [Evidence and traceability](evidence-and-traceability.md), [Evidence publication](evidence-publication.md).

Evidence tooling requires **Python 3.10 or newer**. Conda is optional and is not required.

```bash
python3 --version
python3 -m pip install -r tools/requirements-evidence-export.txt
```

Use placeholder suffix variables from your local runs. Never paste real suffixes into documentation.

```bash
: "${INGESTION_SUFFIX:?Set INGESTION_SUFFIX from the Ingestion API run}"
: "${WFS_JUNTAS_SUFFIX:?Set WFS_JUNTAS_SUFFIX from the juntas run}"
: "${WFS_CITY_SUFFIX:?Set WFS_CITY_SUFFIX from the city run}"
: "${SPARQL_SUFFIX:?Set SPARQL_SUFFIX from the SPARQL run}"
```

COMPLETE and SINGLE use independent timestamps and export directories. Run SINGLE after COMPLETE without overwriting COMPLETE artifacts.

### COMPLETE example

This assignment is an example only. Slot order is arbitrary:

- T1 = Ingestion API
- T2 = WFS juntas
- T3 = WFS city
- T4 = SPARQL

```bash
COMPLETE_TS=$(date +%Y%m%d_%H%M%S)
COMPLETE_EXPORT_DIR="reports/exports/complete_$COMPLETE_TS"
COMPLETE_WORKBOOK="$COMPLETE_EXPORT_DIR/ippcp_evidence_summary_${COMPLETE_TS}.xlsx"
COMPLETE_ZIP="$COMPLETE_EXPORT_DIR/ippcp_evidence_package_${COMPLETE_TS}.zip"
COMPLETE_TESTS="T1=$INGESTION_SUFFIX,T2=$WFS_JUNTAS_SUFFIX,T3=$WFS_CITY_SUFFIX,T4=$SPARQL_SUFFIX"

python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$COMPLETE_TESTS" \
  --timestamp "$COMPLETE_TS" \
  --export-dir "$COMPLETE_EXPORT_DIR" \
  --strict

python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$COMPLETE_TESTS" \
  --excel "$COMPLETE_WORKBOOK" \
  --timestamp "$COMPLETE_TS" \
  --export-dir "$COMPLETE_EXPORT_DIR" \
  --strict
```

Use the same `COMPLETE_TS` for the workbook and the ZIP. Do not recompute it between the two commands.

Inspect publication status from the generated ZIP:

```bash
unzip -p "$COMPLETE_ZIP" ippcp_evidence_package/package_status.json | jq '{publication_ready, publication_blockers}'
unzip -p "$COMPLETE_ZIP" ippcp_evidence_package/slot_inventory.json | jq .
```

`publication_ready=true` means package policies permit publication. Manual review is still required.

`publication_ready=false` means this is an internal artifact. Do not share it externally.

A COMPLETE package that includes WFS or SPARQL is normally `publication_ready=false`.

**STOP if:** `publication_ready=false` and the artifact is intended for external sharing.

### SINGLE example

SINGLE is independently executable after COMPLETE. It uses its own timestamp and export directory.

This deliberately puts Ingestion API in T3 to show slot independence.

The workbook is a local review artifact. `minimal_publication` excludes Excel from the publication ZIP, so the package command does not receive `--excel`. That allows `--strict` package validation without weakening the command.

```bash
SINGLE_TS=$(date +%Y%m%d_%H%M%S)
SINGLE_EXPORT_DIR="reports/exports/single_$SINGLE_TS"
SINGLE_WORKBOOK="$SINGLE_EXPORT_DIR/ippcp_evidence_summary_${SINGLE_TS}.xlsx"
SINGLE_ZIP="$SINGLE_EXPORT_DIR/ippcp_evidence_package_${SINGLE_TS}.zip"
SINGLE_TESTS="T3=$INGESTION_SUFFIX"

python3 tools/export_evidence_to_excel.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$SINGLE_TESTS" \
  --timestamp "$SINGLE_TS" \
  --export-dir "$SINGLE_EXPORT_DIR" \
  --strict

python3 tools/package_evidence_bundle.py \
  --config tools/evidence_export.tests.yaml \
  --tests "$SINGLE_TESTS" \
  --timestamp "$SINGLE_TS" \
  --export-dir "$SINGLE_EXPORT_DIR" \
  --strict
```

`--tests "T3=$INGESTION_SUFFIX"` is already exact. Golden Path SINGLE does not need `--only-tests`.

Inspect publication status:

```bash
unzip -p "$SINGLE_ZIP" \
  ippcp_evidence_package/package_status.json \
  | jq '{publication_ready, publication_blockers}'

unzip -p "$SINGLE_ZIP" \
  ippcp_evidence_package/slot_inventory.json \
  | jq .
```

A current SINGLE ingestion-only package may be `publication_ready=true`. Manual review is still required before any external sharing.

**STOP if:** `publication_ready=false` and the artifact is intended for external sharing.

### `publication_ready`

Each classified asset has `publication_profile` and `publication_safe`.

- `minimal_publication` → `publication_safe=true` (current Ingestion API v2 profile).
- `standard` → `publication_safe=false` (current WFS, SPARQL, and legacy CSV/B2 profile).

```text
package.publication_ready = all included slots are publication_safe
```

## 14. Stop conditions

STOP if:

- Phase 0 fails;
- the expected `phase*_env.sh` file is missing;
- credentials are missing or still set to placeholders;
- `git check-ignore` does not list every local secret listed in [section 5](#5-verify-secrets-are-ignored-by-git);
- semantic validation fails;
- run phases are not all `ok`;
- `publication_ready=false` and the artifact is intended for external sharing;
- HTTP 409 occurs in Phase 1 (start a new run instead of mutating the asset);
- SPARQL returns XML;
- WFS JSON is not a `FeatureCollection`;
- you are about to print passwords, API keys, JWTs, or EDR authorization.

## 15. Security

Never place in repository documentation, commits, screenshots, recordings, or public packages:

- real passwords;
- real API keys;
- JWT / Bearer tokens;
- EDR authorization;
- actual `user_*.sh` contents;
- actual `ingesta_api_key.env`;
- current real `SUFFIX` values;
- personal local paths;
- sensitive payloads.

Before recording a demo: `set +x`, keep the terminal clean, and do not open `user_*.sh`, `ingesta_api_key.env`, or `phase*_env.sh` on screen.

Provider EdD credentials authenticate connectors. The Ingestion API key protects a different hop and must not be shared with the consumer.

## 16. Reference documentation

This workshop is the executable path. The following documents are detailed reference:

- [Getting started](getting-started.md)
- [Execution phases](execution-phases.md)
- [Ingestion API](flows/ingestion-api.md)
- [WFS](flows/wfs.md)
- [SPARQL](flows/sparql.md)
- [Evidence and traceability](evidence-and-traceability.md)
- [Evidence publication](evidence-publication.md)
- [Troubleshooting](troubleshooting.md)
- [Authentication](authentication.md)
- [Architecture](architecture.md)
- [tools/tools_README.md](../tools/tools_README.md)
- [tools/evidence_tooling.md](../tools/evidence_tooling.md)

## 17. Legacy / reference material

Current Golden Path:

- `v2`
- `HttpData-PULL`
- `phase0` → `phase4`

Historical / reference only. Do not mix into this workshop:

- CSV / B2 / InesDataStore
- `v1`
- `test3`
- `phase1b_provider_upload_file.sh`
- `phase3b_inesdata_transfer.sh`
- `phase4b_consumer_storage_fetch.sh`

Those paths remain in the repository for reproducibility. They are not the recommended route for new tests or the current demo.
