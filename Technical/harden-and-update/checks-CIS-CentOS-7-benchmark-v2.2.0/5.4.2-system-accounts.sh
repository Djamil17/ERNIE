#!/usr/bin/env bash
echo "5.4.2 Ensure system accounts are non-login"
echo "___CHECK___"
while IFS=: read -r user enc_passwd uid gid full_name home shell; do
  if [[ "$user" != "root" && "$user" != "sync" && "$user" != "shutdown" && "$user" != "halt" ]] && \
        ((uid < MIN_NON_SYSTEM_UID)) && [[ "$shell" != "/sbin/nologin" && "$shell" != "/bin/false" ]]; then
    echo "Check FAILED..."
    echo "$user:$uid:$gid:$full_name:$home:$shell"
    echo "___SET___"
    usermod --lock "${user}"
    usermod --shell /sbin/nologin "${user}"
  fi
done < <(grep -E -v "^\+" /etc/passwd)
echo "Check PASSED"
printf "\n\n"
