#!/usr/bin/env bash
set -euxo pipefail

pr_numbers="$(gh pr list \
  --state open \
  --json number,labels,body \
  --jq '.[]
    | select(any(.labels[]; .name == "dependencies"))
    | select(any(.labels[]; .name | test("^jdk[0-9]+$")))
    | select((.body // "") | contains("<!-- pr-title-updated -->") | not)
    | .number')"

if [[ -n "${pr_numbers}" ]]; then
  while read -r pr_number; do
    pr_data=$(gh pr view "${pr_number}" --json title,body)

    body="$(jq -r '.body' <<< "${pr_data}")"
    architectures="$(grep '<summary>' <<< "${body}" | grep 'Bump' | sed -E 's|.*Installer URL for (.*)</summary>|\1|' | tr -d '\r')"
    architecture_list=""
    while IFS= read -r architecture; do
      [[ -n "${architecture_list}" ]] && architecture_list+=", "
      architecture_list+="\`${architecture}\`"
    done <<< "${architectures}"

    original_title="$(jq -r '.title' <<< "${pr_data}")"
    title="${original_title} (${architecture_list})"
    updated_body="${body}\r\n<!-- pr-title-updated -->"

    gh pr edit "${pr_number}" --title "${title}" --body "${updated_body}"
  done <<< "${pr_numbers}"
else
  echo 'No pull request with "dependencies" and "jdk<N>" labels not updated yet found'
fi
