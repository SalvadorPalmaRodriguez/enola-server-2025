#!/usr/bin/env bash
# Copyright (c) 2025 Salvador Palma Rodríguez
# Enola Server - Licencia de Uso No Comercial
# Consulta LICENSE para términos completos
# Prohibido uso comercial y empresarial
set -euo pipefail

# Simple, non-destructive health check for Enola stack
# Validates:
# 1) nginx -t
# 2) systemctl is-active enola-tor
# 3) tor/list_services.sh runs without error (non-root friendly)
# 4) sshd/nginx listeners sanity

print() { echo -e "[SMOKE] $(date '+%F %T') | $*"; }
pass()  { print "✅ $*"; }
fail()  { print "❌ $*"; }
warn()  { print "⚠️  $*"; }

OK=true

print "Starting smoke test..."

# 1) nginx -t
if command -v nginx >/dev/null 2>&1; then
    if nginx -t >/dev/null 2>&1; then
        pass "nginx -t OK"
    else
        fail "nginx -t FAILED"
        OK=false
    fi
else
    warn "nginx not installed or not in PATH"
fi

# 2) enola-tor active
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet enola-tor; then
        pass "enola-tor is active"
    else
        fail "enola-tor is NOT active"
        OK=false
    fi
else
    warn "systemctl not available"
fi

# 3) list_services.sh
LS="/opt/enola/scripts/tor/list_services.sh"
if [[ -x "$LS" ]]; then
    if "$LS" >/dev/null 2>&1; then
        pass "list_services.sh ran successfully"
    else
        fail "list_services.sh returned error"
        OK=false
    fi
else
    warn "list_services.sh not found or not executable: $LS"
fi

# Helper: read SSH ports from config (fallback to 22)
read_ssh_ports() {
    local ports=()
    local main_cfg="/etc/ssh/sshd_config"
    if [[ -r "$main_cfg" ]]; then
        while read -r p; do
            ports+=("$p")
        done < <(awk 'tolower($1)=="port" {print $2}' "$main_cfg" 2>/dev/null)
    fi
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [[ -r "$f" ]] || continue
        while read -r p; do
            ports+=("$p")
        done < <(awk 'tolower($1)=="port" {print $2}' "$f" 2>/dev/null)
    done
    if [[ ${#ports[@]} -eq 0 ]]; then
        ports=(22)
    fi
    printf '%s\n' "${ports[@]}" | awk '!seen[$0]++'
}

# Helper: read nginx listen ports from enabled sites
read_nginx_ports() {
    local ports=()
    local sites_found=false
    
    for f in /etc/nginx/sites-enabled/*.conf; do
        [[ -r "$f" ]] || continue
        sites_found=true
        # capture: listen 80; listen [::]:80; listen 443 ssl; etc.
        while read -r p; do
            ports+=("$p")
        done < <(awk '/^[^#].*listen[[:space:]]/ {for(i=1;i<=NF;i++){if($i~/^[0-9]+;?$/){gsub(";","",$i); print $i}else if($i~/:[0-9]+;?$/){gsub(";","",$i); sub(/.*:/, "", $i); print $i}}}' "$f" 2>/dev/null)
    done
    
    # Si no hay sites configurados, no esperar puertos (en vez de fallback a 80/443)
    if [[ ${#ports[@]} -eq 0 ]]; then
        return 1  # Indicar que no hay puertos configurados
    fi
    
    printf '%s\n' "${ports[@]}" | awk '!seen[$0]++'
    return 0
}

# 4) listeners: sshd and nginx
SS_CMD="ss -ltn"
# Prefer showing process info if available; fall back silently
if ss -ltnp >/dev/null 2>&1; then
    SS_CMD="ss -ltnp"
fi

# sshd - Solo verificar si el usuario lo ha habilitado
SSH_CHECK_ENABLED="/var/lib/enola-server/ssh_check_enabled"
if [[ -f "$SSH_CHECK_ENABLED" ]]; then
    SSH_OK=true
    if pgrep -x sshd >/dev/null 2>&1; then
        while read -r port; do
            if $SS_CMD 2>/dev/null | grep -q ":$port\b"; then
                :
            else
                SSH_OK=false
                warn "sshd process running but no LISTEN on port $port"
            fi
        done < <(read_ssh_ports)
        if $SSH_OK; then pass "sshd listening on configured ports"; else OK=false; fi
    else
        fail "sshd check enabled but process not found"
        OK=false
    fi
else
    # SSH check no habilitado - informar pero no como error
    print "ℹ️  sshd check is disabled (enable from system config menu)"
fi

# nginx
NGX_OK=true
if pgrep -x nginx >/dev/null 2>&1; then
    # Intentar leer puertos configurados
    if nginx_ports=$(read_nginx_ports); then
        # Hay sites configurados, validar que NGINX escucha en esos puertos
        while read -r port; do
            if $SS_CMD 2>/dev/null | grep -q ":$port\b"; then
                :
            else
                NGX_OK=false
                warn "nginx process running but no LISTEN on port $port"
            fi
        done <<< "$nginx_ports"
        if $NGX_OK; then 
            pass "nginx listening on expected ports"
        else 
            OK=false
        fi
    else
        # No hay sites configurados, NGINX puede estar corriendo sin escuchar
        pass "nginx running (no sites configured yet, skipping port check)"
    fi
else
    warn "nginx process not found (may be stopped if no sites)"
fi

if $OK; then
    print "All checks PASS"
    exit 0
else
    print "Some checks FAILED"
    exit 1
fi
