#!/bin/bash

# Script de Monitoreo de Forks - Enola Server
# Cualquier usuario puede ejecutar este script para ver todos los forks públicos
# y ayudar a detectar violaciones de licencia.

REPO="SalvadorPalmaRodriguez/enola-server-2025"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     🔍 MONITOREO DE FORKS - ENOLA SERVER v1.0.0              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Este script muestra todos los forks públicos del repositorio."
echo "Ayúdanos a proteger el proyecto reportando usos comerciales no autorizados."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar si gh está instalado
if ! command -v gh &> /dev/null; then
    echo "❌ ERROR: 'gh' (GitHub CLI) no está instalado."
    echo ""
    echo "Instalar con:"
    echo "  sudo apt install gh"
    echo "  gh auth login"
    exit 1
fi

# Verificar si jq está instalado
if ! command -v jq &> /dev/null; then
    echo "❌ ERROR: 'jq' no está instalado."
    echo ""
    echo "Instalar con:"
    echo "  sudo apt install jq"
    exit 1
fi

# Obtener forks
echo "📊 Consultando forks en GitHub..."
echo ""

FORKS=$(gh api "repos/$REPO/forks?per_page=100" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ ERROR: No se pudo consultar la API de GitHub."
    echo "   Asegúrate de estar autenticado: gh auth login"
    exit 1
fi

FORK_COUNT=$(echo "$FORKS" | jq '. | length')

if [ "$FORK_COUNT" -eq 0 ]; then
    echo "✅ No hay forks registrados actualmente."
    echo ""
    echo "   Esto es bueno - significa que nadie ha forkeado el proyecto todavía."
    exit 0
fi

echo "📋 Total de forks encontrados: $FORK_COUNT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Listar forks con detalles
echo "$FORKS" | jq -r '.[] | 
    "👤 Usuario: \(.owner.login)\n" +
    "🔗 URL: \(.html_url)\n" +
    "📅 Creado: \(.created_at)\n" +
    "⭐ Stars: \(.stargazers_count)\n" +
    "🍴 Forks del fork: \(.forks_count)\n" +
    "�� Descripción: \(.description // "Sin descripción")\n" +
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"'

echo ""
echo "⚠️  RECORDATORIO SOBRE LA LICENCIA:"
echo ""
echo "   ✅ Permitido: Uso personal, educativo, estudio del código"
echo "   ❌ PROHIBIDO: Uso comercial, redistribución, competencia"
echo ""
echo "   Si detectas algún fork con:"
echo "     • Uso comercial sin autorización"
echo "     • Redistribución del software"
echo "     • Eliminación de avisos de copyright"
echo "     • Competencia comercial"
echo ""
echo "   Por favor, reporta a: salvadorpalmarodriguez@gmail.com"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Monitoreo completado. Gracias por ayudar a proteger el proyecto."
echo ""
