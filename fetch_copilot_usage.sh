#!/bin/bash

. .env
# Read the VUE_APP_GITHUB_TEAMS environment variable
teams=$(echo $VUE_APP_GITHUB_TEAMS | tr ',' '\n')
teams="$teams"$'\n'"all-teams"

# Loop through each team name
for team in $teams; do
  echo Processing $team
  # Define the output file path
  output_file="data/copilot-usage-$team.json"

  # Check if the file exists, if not create it with an empty array
  if [ ! -f "$output_file" ]; then
    echo "[]" > "$output_file"
  fi
  # Fetch the data using curl
  if [ "$team" == "all-teams" ]; then
    url="https://api.github.com/orgs/netskope/copilot/usage"
  else
    url="https://api.github.com/orgs/netskope/team/$team/copilot/usage"
  fi
  new_data=$(curl -s -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $VUE_APP_GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$url")

  # Check if new_data is valid JSON and is an array
  if echo "$new_data" | jq -e . > /dev/null 2>&1 && echo "$new_data" | jq -e 'if type == "array" then . else empty end' > /dev/null 2>&1; then
    # Combine new_data with the contents of output_file, treating the data as a set with a key on "day"
    jq -s 'add | unique_by(.day)' "$output_file" <(echo "$new_data") > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
  else
    echo "Error: Invalid JSON data fetched for team $team"
  fi
done