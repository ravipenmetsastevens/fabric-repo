# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

# Welcome to your new notebook
# Type here in the cell editor to add code!


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests

# Fill these in
account = "StevensTransport"
user = "StevensAPIUser"
password = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "ORIGAMIPWD"
)  # use this if your “key” is actually the password
client_name = "Stevens Transport"

# 1) Ping
ping_url = "https://live.origamirisk.com/OrigamiApi/Authentication/Ping"
ping_response = requests.get(ping_url, timeout=30)

print("PING STATUS:", ping_response.status_code)
print("PING BODY:", ping_response.text)

# 2) Authenticate
auth_url = "https://live.origamirisk.com/OrigamiApi/Authentication/Authenticate"
payload = {
    "Account": account,
    "User": user,
    "Password": password,
    "ClientName": client_name
}

auth_response = requests.post(auth_url, json=payload, timeout=30)

print("AUTH STATUS:", auth_response.status_code)
print("AUTH BODY:", auth_response.text)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests

token = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "ORIGAMITOKEN"
)

url = "https://live.origamirisk.com/OrigamiApi/api/Claim/Query"

headers = {
    "accept": "application/json",
    "Token": token
}

response = requests.get(url, headers=headers)
print(response.status_code)
print(response.text)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests

token = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "ORIGAMITOKEN"
)
headers = {
    "accept": "application/json",
    "Token": token
}

urls = [
    "https://live.origamirisk.com/OrigamiApi/api/Claim/fields",
    "https://live.origamirisk.com/OrigamiApi/api/Claim/10105",
    "https://live.origamirisk.com/OrigamiApi/api/Claim/Query?columns=ClaimNumber"
]

for url in urls:
    r = requests.get(url, headers=headers)
    print(url)
    print(r.status_code)
    print(r.text[:2000])
    print("-" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json

ACCOUNT = "StevensTransport"
USER = "StevensAPIUser"
PASSWORD = "8c524a58-5316-477d-91b9-62677eab5bff"
CLIENT_NAME = "Stevens Transport"

BASE = "https://live.origamirisk.com/OrigamiApi"

# -----------------------------
# Step 1: authenticate
# -----------------------------
auth_payload = {
    "Account": ACCOUNT,
    "User": USER,
    "Password": PASSWORD,
    "ClientName": CLIENT_NAME
}

auth = requests.post(
    f"{BASE}/Authentication/Authenticate",
    json=auth_payload,
    timeout=30
)
auth.raise_for_status()

token = auth.json()["Token"]

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# -----------------------------
# Step 2: confirm domains
# -----------------------------
r = requests.get(f"{BASE}/api/Domains", headers=headers, timeout=30)
r.raise_for_status()
print("DOMAINS:")
print(json.dumps(r.json(), indent=2))

# -----------------------------
# Step 3: inspect metadata for each target domain
# replace endpoint if your portal shows a slightly different metadata path
# -----------------------------
target_domains = ["Claim", "Incident", "Location", "Vehicle", "Employee", "File", "Transaction"]

for domain in target_domains:
    print(f"\n--- DOMAIN: {domain} ---")
    url = f"{BASE}/api/Domains/{domain}/Fields"   # verify exact metadata path in portal
    resp = requests.get(url, headers=headers, timeout=30)
    print("STATUS:", resp.status_code)
    print(resp.text[:4000])

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
