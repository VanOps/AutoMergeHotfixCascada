#!/bin/bash
# setup-release-branches.sh - Crea estructura de ramas de release para hotfix cascade

set -e

echo "🔧 Configurando ramas de release para Hotfix Cascade..."

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que estamos en un repo git
if [ ! -d .git ]; then
    echo -e "${RED}❌ Error: No estás en un repositorio git${NC}"
    exit 1
fi

# Verificar que existe develop
if ! git show-ref --verify --quiet refs/heads/develop; then
    echo -e "${YELLOW}⚠️  Rama 'develop' no existe. Creándola...${NC}"
    git checkout -b develop
    git push -u origin develop
fi

# Asegurarse de estar en develop actualizado
echo -e "${GREEN}📥 Actualizando develop...${NC}"
git checkout develop
git pull origin develop

# Array de versiones de release a crear
RELEASES=("1.0" "1.1" "2.0")

# Crear ramas de release
for version in "${RELEASES[@]}"; do
    BRANCH="release/$version"
    
    if git show-ref --verify --quiet refs/heads/$BRANCH; then
        echo -e "${YELLOW}⚠️  Rama $BRANCH ya existe${NC}"
    else
        echo -e "${GREEN}✨ Creando rama $BRANCH...${NC}"
        git checkout -b $BRANCH develop
        
        # Crear archivo de release notes
        cat > RELEASE-$version.md <<EOF
# Release $version

## Cambios
- Versión inicial de release $version

## Fecha de creación
$(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Branch strategy
Esta rama es parte de la estrategia de hotfix cascade.
Los hotfixes aplicados a versiones anteriores se propagarán automáticamente.
EOF
        
        git add RELEASE-$version.md
        git commit -m "chore: Initialize release/$version branch"
        git push -u origin $BRANCH
        
        echo -e "${GREEN}✅ Rama $BRANCH creada y pusheada${NC}"
    fi
done

# Volver a develop
git checkout develop

echo ""
echo -e "${GREEN}✅ Configuración completa!${NC}"
echo ""
echo "Ramas creadas:"
git branch -r | grep release/

echo ""
echo "📝 Próximos pasos:"
echo "1. Configura branch protection en GitHub para develop y main"
echo "2. Configura permisos de GitHub Actions (Settings > Actions > General)"
echo "3. Si usas protected branches, crea un PAT y agrégalo como secret MERGE_TOKEN"
echo ""
echo "Para crear un hotfix de prueba:"
echo "  git checkout release/1.0"
echo "  git checkout -b hotfix/test-cascade"
echo "  echo 'test fix' >> test.txt"
echo "  git add test.txt"
echo "  git commit -m 'fix: test cascade merge'"
echo "  git push -u origin hotfix/test-cascade"
echo "  # Luego crea un PR a release/1.0 en GitHub"
