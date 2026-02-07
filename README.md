# Automerge de Hotfix con Cascada - Implementación de Ejemplo

Este submódulo contiene una implementación completa de la estrategia de **Hotfix Cascade AutoMerge** usando GitHub Actions.

## 📁 Estructura del Proyecto

```
.
├── .github/
│   └── workflows/
│       ├── cascade-merge.yml    # Workflow principal de cascada automática
│       └── setup-ci.yml         # CI/CD para validar cambios
├── src/                         # Aplicación Next.js de ejemplo
│   ├── app/                     # App Router de Next.js
│   ├── public/                  # Archivos estáticos
│   └── package.json             # Dependencias de Next.js
├── setup-release-branches.sh   # Script para crear ramas de release
└── README.md

```

## 🚀 Inicio Rápido

### 1. Configurar Ramas de Release

Ejecuta el script de configuración para crear la estructura de ramas:

```bash
./setup-release-branches.sh
```

Esto creará:
- `release/1.0`
- `release/1.1`
- `release/2.0`
- `develop` (si no existe)

### 2. Configurar GitHub

**En Settings > Actions > General > Workflow permissions**:
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

**En Settings > General > Pull Requests**:
- ❌ Desmarcar "Automatically delete head branches"

### 3. Crear un Hotfix de Prueba

```bash
# Crear hotfix desde release/1.0
git checkout release/1.0
git checkout -b hotfix/test-cascade

# Hacer cambio en la aplicación Next.js
cd src
echo "export const HOTFIX_VERSION = '1.0.1';" > app/config.ts
cd ..

git add src/app/config.ts
git commit -m "fix: Add hotfix version constant"
git push -u origin hotfix/test-cascade
```

### 4. Crear Pull Request

1. Ve a GitHub y crea un PR de `hotfix/test-cascade` → `release/1.0`
2. Espera a que pasen los checks de CI
3. Aprueba y mergea el PR
4. **Observa la cascada automática**: El workflow creará automáticamente PRs hacia:
   - `release/1.0` → `release/1.1`
   - `release/1.1` → `release/2.0`
   - `release/2.0` → `develop`

## 🔄 Cómo Funciona

### Workflow de Cascada (`cascade-merge.yml`)

- **Trigger**: Se ejecuta cuando un PR es mergeado
- **Condiciones**: Solo actúa en PRs de `release/*` o `hotfix/*`
- **Acción**: Usa `ActionsDesk/cascading-downstream-merge` para propagar cambios

### Workflow de CI (`setup-ci.yml`)

- **Trigger**: PRs y pushes a ramas de release, develop o main
- **Validaciones**:
  - Linter (ESLint)
  - Build de Next.js
  - Security audit
  - Scan de secretos

## 📱 Aplicación Next.js

El directorio `src/` contiene una aplicación Next.js 16 que sirve como ejemplo para validar la estrategia:

```bash
cd src

# Desarrollo local
npm install
npm run dev

# Build
npm run build

# Linter
npm run lint
```

## 🔧 Configuración Avanzada

### Branch Protection (Opcional)

Para `develop` y `main`:

```
Settings > Branches > Add branch protection rule

Branch name pattern: develop

☑ Require pull request before merging
☑ Require status checks to pass: 
  - test
  - security-scan
```

### Personal Access Token (PAT)

Si usas branch protection, necesitas un PAT:

1. **Settings (perfil) > Developer settings > Personal access tokens > Tokens (classic)**
2. Scopes: `repo`, `workflow`
3. **Repo > Settings > Secrets > New repository secret**
4. Nombre: `MERGE_TOKEN`

Luego, actualiza `cascade-merge.yml`:

```yaml
- name: 🚀 Cascading Auto-Merge
  uses: ActionsDesk/cascading-downstream-merge@v3.0.0
  with:
    merge_token: ${{ secrets.MERGE_TOKEN }}  # Usar en lugar de GITHUB_TOKEN
    prefixes: release/
    ref_branch: develop
```

## 📝 Ejemplo de Flujo Completo

```bash
# 1. Crear hotfix crítico
git checkout release/1.0
git checkout -b hotfix/security-cve-2026

# 2. Hacer el fix en Next.js
cd src/app
echo "// FIXED: CVE-2026-12345" > security-patch.ts
cd ../..

git add .
git commit -m "fix: Patch SQL injection vulnerability (CVE-2026-12345)"
git push -u origin hotfix/security-cve-2026

# 3. Crear PR en GitHub: hotfix/security-cve-2026 → release/1.0
# 4. CI valida cambios automáticamente
# 5. Aprobar y mergear
# 6. Cascada automática propaga a release/1.1, release/2.0, develop
```

## 🛠️ Troubleshooting

### La cascada no se inicia

```bash
# Ver workflows ejecutados
gh run list --workflow="Hotfix Cascading Auto-Merge"

# Ver logs específicos
gh run view <RUN_ID> --log
```

### CI falla en Next.js build

```bash
# Verificar localmente
cd src
npm install
npm run build
```

### Conflictos en la cascada

Si hay conflictos, la cascada se detiene:

```bash
# Resolver manualmente
git checkout release/1.1
git merge release/1.0
# Resolver conflictos
git add .
git commit
git push
```

## 📚 Documentación

Ver [docs/HotfixCascada.md](../../docs/HotfixCascada.md) en el repositorio principal para documentación completa.

## 📄 Licencia

MIT - Ver [LICENSE](LICENSE)