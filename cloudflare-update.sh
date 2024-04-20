#!/usr/bin/env bash

CONFIG_FILE="$1"
ZONE="$2"
comment_filter="${3:-configured by nix}"
TOKEN_FILE="$(jq -r --arg zonename "$ZONE" '.[$zonename].apiKeyPath' "$CONFIG_FILE")"
TOKEN="$(cat "$TOKEN_FILE")"

zone_id="$(curl -s "https://api.cloudflare.com/client/v4/zones/"  \
    -H "Authorization: Bearer $TOKEN" \
    | jq -r --arg zonename "$ZONE" '.result[]|select(.name==$zonename)|.id')"

if [ -n "$zone_id" ]; then
    echo "Zone with name '${ZONE}' has id '${zone_id}'"
else
    >&2 echo "no zone found with name $ZONE"
    exit 1
fi

current_state=$(mktemp)
curl -s "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"  \
    -H "Authorization: Bearer $TOKEN" | jq '.result' > "$current_state"

# check all new records

jq -r --arg zonename "$ZONE" '.[$zonename].records[]|[.name, .type, .content, .comment, .proxied] |@tsv' "$CONFIG_FILE" | \
while IFS=$'\t' read -r name type content comment proxied; do
    if jq -e --arg recordname "$name" '.[]|select(.name==$recordname)' "$current_state"; then
        echo "Found existing record for ${name}. It will be updated"
        record_id=$(jq -r --arg recordname "$name" '.[]|select(.name==$recordname)|.id' "$current_state")
        curl --request PATCH \
            --url "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            --header 'Content-Type: application/json' \
            -H "Authorization: Bearer $TOKEN" \
            --data '{
                    "content": "'"${content}"'",
                    "name": "'"${name}"'",
                    "proxied": false,
                    "type": "'"${type}"'",
                    "comment": "'"${comment}"'",
                    "tags": [ ],
                    "ttl": 1
                }'
    else
        echo "No existing record for ${name}. It will be created"
        curl --request POST \
            --url "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            --header 'Content-Type: application/json' \
            -H "Authorization: Bearer $TOKEN" \
            --data '{
                    "content": "'"${content}"'",
                    "name": "'"${name}"'",
                    "proxied": false,
                    "type": "'"${type}"'",
                    "comment": "'"${comment}"'",
                    "tags": [ ],
                    "ttl": 1
                }'
    fi
done

jq -r '.[]|[.name, .type, .content, .comment, .id] |@tsv' "$current_state" | \
while IFS=$'\t' read -r name type content comment record_id; do
    if ! jq -e --arg zonename "$ZONE" --arg recordname "$name" '.[$zonename].records[]|select(.name==$recordname)' "$CONFIG_FILE"; then
        if [[ "$comment" == "$comment_filter" ]]; then
            echo "DNS record for ${name} was created by nix, but it isn't in new config. will delete"
            curl -s --request DELETE \
                --url "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
                --header 'Content-Type: application/json' \
                -H "Authorization: Bearer $TOKEN"
        else
            echo "DNS record for ${name} exists but was not created by nix. ignorning"
        fi
    fi
done
